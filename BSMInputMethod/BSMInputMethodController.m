//
//  BSMInputMethodController.m
//  BSMInputMethod
//
//  Created by Chong Francis on 13年5月10日.
//  Copyright (c) 2013年 Ignition Soft. All rights reserved.
//

#import <Carbon/Carbon.h>

#import "BSMInputMethodController.h"
#import "BSMEngine.h"
#import "BSMMatch.h"
#import "BSMAppDelegate.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

@implementation BSMInputMethodController

- (id)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self) {
        self.candidateWindow = [BSMAppDelegate sharedCandidatesWindow];
        self.buffer = [[BSMBuffer alloc] initWithEngine:[BSMAppDelegate sharedEngine]];
    }
    return self;
}

-(void) dealloc {
    self.candidateWindow = nil;
    self.buffer = nil;
}

-(BOOL)inputText:(NSString*)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {
    DDLogVerbose(@"Called inputText:%@ key:%ld modifiers:%lx client:%@", string, keyCode, flags, sender);

    if (keyCode == kVK_ANSI_KeypadDecimal) {
        if (self.buffer.inputBuffer.length > 0) {
            if (self.buffer.selectionMode) {
                // if user already in selection mode, select the first word
                [self selectFirstCandidate:sender];
            } else {
                // otherwise enter selection mode
                [self appendBuffer:string client:sender];
            }
            return YES;
        }

    } else if (keyCode >= kVK_ANSI_Keypad0 && keyCode <= kVK_ANSI_Keypad9) {
        if (self.buffer.selectionMode) {
            // in selection mode, if user enter 1-9, apply the word
            if (keyCode > kVK_ANSI_Keypad0) {
                NSUInteger selectionIndex = 0;
                switch (keyCode) {
                    case kVK_ANSI_Keypad1:
                    case kVK_ANSI_Keypad2:
                    case kVK_ANSI_Keypad3:
                    case kVK_ANSI_Keypad4:
                    case kVK_ANSI_Keypad5:
                    case kVK_ANSI_Keypad6:
                    case kVK_ANSI_Keypad7:
                        selectionIndex = keyCode - kVK_ANSI_Keypad1;
                        break;
                    case kVK_ANSI_Keypad8:
                        selectionIndex = 7;
                        break;
                    case kVK_ANSI_Keypad9:
                        selectionIndex = 8;
                        break;
                    default:
                        break;
                }

                if ([self.buffer setSelectedIndex:selectionIndex]) {
                    [self commitComposition:sender];
                } else {
                    [self beep];
                }
                return YES;
            } else {
                [self beep];
            }

            return YES;
        } else if (self.buffer.inputBuffer.length < 6) {
            return [self appendBuffer:string client:sender];
        } else {
            [self beep];
            return YES;
        }

    } else if (keyCode == kVK_ANSI_KeypadMinus) {
        return [self minusBuffer:sender];

    } else if (keyCode == kVK_ANSI_KeypadPlus) {
        if (self.buffer.inputBuffer.length > 0) {
            DDLogInfo(@"toggle show candidate code");
            if ([self.candidateWindow isShowingCandidatesCode]) {
                [self.candidateWindow hideCandidatesCode];
            } else {
                [self.candidateWindow showCandidatesCode];
            }
            return YES;
        }

    } else if (keyCode == kVK_ANSI_KeypadEnter) {
        if (self.buffer.composedString.length > 0) {
            return [self selectFirstCandidate:sender];
        }

    } else if (keyCode == kVK_ANSI_KeypadDivide) {
        if (self.buffer.inputBuffer.length > 0) {
            if ([self.buffer nextPage]) {
                [self beep];
            }
            [self showCandidateWindowWithClient:sender];
            return YES;
        }

    } else if (keyCode == kVK_ANSI_KeypadEquals) {
        if (self.buffer.inputBuffer.length > 0) {
            if ([self.buffer previousPage]) {
                [self beep];
            }
            [self showCandidateWindowWithClient:sender];
            return YES;
        }

    } else if (keyCode == kVK_ANSI_KeypadClear) {
        [self clearInput:sender];
        return YES;

    }

    return NO;
}

-(BOOL) appendBuffer:(NSString*)string client:(id)sender {
    @synchronized(self) {
        [self.buffer appendBuffer:string];

        NSString* marker = self.buffer.marker;
        DDLogVerbose(@"%@", marker);
        [sender setMarkedText:marker
               selectionRange:NSMakeRange(0, [marker length])
             replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

        [self showCandidateWindowWithClient:sender];
        return YES;
    }
}

- (BOOL) minusBuffer:(id)sender {
    @synchronized(self) {
        if (self.buffer.inputBuffer.length > 0) {
            [self.buffer deleteBackward];
            NSString* marker = self.buffer.marker;
            DDLogVerbose(@"%@", marker);
            
            [sender setMarkedText:marker
                   selectionRange:NSMakeRange(0, [marker length])
                 replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
            
            if (self.buffer.composedString.length > 0) {
                [self showCandidateWindowWithClient:sender];
            } else {
                [self hideCandidateWindow];
            }
            return YES;
        } else {
            return NO;
        }
    }
}

- (void) clearInput:(id)sender {
    @synchronized(self) {
        DDLogVerbose(@"clear input");
        [sender setMarkedText:@""
               selectionRange:NSMakeRange(NSNotFound,NSNotFound)
             replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
        [self reset];
        [self cancelComposition];
    }
}

- (BOOL) selectFirstCandidate:(id)sender {
    if ([self.buffer.candidates count] > 0 && self.buffer.composedString.length > 0) {
        [self commitComposition:sender];
    } else {
        NSBeep();
    }
    return YES;
}

- (NSArray*)candidates:(id)sender {
    NSMutableArray* theCandidates = [NSMutableArray array];
    [self.buffer.candidates enumerateObjectsUsingBlock:^(BSMMatch* match, NSUInteger idx, BOOL *stop) {
        [theCandidates addObject:match.word];
    }];
	return theCandidates;
}

- (void) commitComposition:(id)client {
    @synchronized(self) {
        DDLogVerbose(@"Call commitComposition:%@", client);
        [client insertText:self.buffer.composedString
          replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        [self reset];
        [self hideCandidateWindow];
    }
}

-(void) cancelComposition {
    @synchronized(self) {
        [super cancelComposition];
        [self reset];
        [self hideCandidateWindow];
    }
}

-(void) reset {
    [self.buffer reset];
}

- (void) beep {
    NSBeep();
}

#pragma mark - IMKStateSetting

- (void)activateServer:(id)client {
    [self.buffer reset];
}

- (void)deactivateServer:(id)client {
    [self.candidateWindow hideCandidates];
}

#pragma mark - Private

-(void) showCandidateWindowWithClient:(id)sender {
    @synchronized(self.candidateWindow) {
        // find the position of the window
        NSUInteger cursorIndex = self.selectionRange.location;
        if (cursorIndex == [self.buffer.marker length] && cursorIndex) {
            cursorIndex--;
        }
        DDLogInfo(@"showCandidateWindowWithClient: select range: %@",
                  NSStringFromRange(self.selectionRange));

        NSRect lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);
        @try {
            NSDictionary *attr = [sender attributesForCharacterIndex:cursorIndex lineHeightRectangle:&lineHeightRect];
            if (![attr count]) {
                [sender attributesForCharacterIndex:0 lineHeightRectangle:&lineHeightRect];
            }
        }
        @catch (NSException *exception) {
            DDLogError(@"Exception: cannot find string attribute: %@", [exception debugDescription]);
        }
        
        // show candidate window
        [self.candidateWindow updateCandidates:self.buffer.candidates];
        [self.candidateWindow setWindowTopLeftPoint:lineHeightRect.origin
             bottomOutOfScreenAdjustmentHeight:lineHeightRect.size.height + 4.0];
        [self.candidateWindow showCandidates];
    }
}

-(void) hideCandidateWindow {
    @synchronized(self.candidateWindow) {
        [self.candidateWindow hideCandidates];
    }
}

@end
