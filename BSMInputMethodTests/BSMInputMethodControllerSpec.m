//
//  BSMInputMethod - BSMInputMethodController.m
//  Copyright 2013年 Ignition Soft. All rights reserved.
//
//  Created by: Chong Francis
//

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"
#import "OCMock.h"
#import <Carbon/Carbon.h>
#import <InputMethodKit/InputMethodKit.h>

#import "BSMInputMethodController.h"

SpecBegin(BSMInputMethodController)

describe(@"BSMInputMethodController", ^{
    __block BSMInputMethodController* controller;
    __block id mockServer;
    __block id mockClient;
    __block id mockBuffer;
    __block id mockController;

    before(^{
        mockServer = [OCMockObject niceMockForClass:[IMKServer class]];
        mockClient = [OCMockObject niceMockForProtocol:@protocol(IMKTextInput)];
        controller = [[BSMInputMethodController alloc] initWithServer:nil delegate:nil client:nil];
        mockController = [OCMockObject partialMockForObject:controller];
        controller = mockController;

        mockBuffer = [OCMockObject partialMockForObject:controller.buffer];
        controller.buffer = mockBuffer;
    });
    after(^{
        mockServer = nil;
        mockClient = nil;
        mockController = nil;
        mockBuffer = nil;
        [controller inputControllerWillClose];
        controller = nil;
    });
    
    describe(@"-inputText:key:modifiers:client:",^{
        describe(@"numbers key", ^{
            it(@"should enter input", ^{
                [((BSMBuffer*)[mockBuffer expect]) appendBuffer:@"8"];
                [controller inputText:@"8" key:kVK_ANSI_Keypad8 modifiers:0 client:mockClient];
                [mockBuffer verify];
            });
            
            it(@"should not allow enter more than 6 input key", ^{
                [controller inputText:@"8" key:kVK_ANSI_Keypad8 modifiers:0 client:mockClient];
                [controller inputText:@"8" key:kVK_ANSI_Keypad8 modifiers:0 client:mockClient];
                [controller inputText:@"1" key:kVK_ANSI_Keypad1 modifiers:0 client:mockClient];
                [controller inputText:@"1" key:kVK_ANSI_Keypad1 modifiers:0 client:mockClient];
                [controller inputText:@"9" key:kVK_ANSI_Keypad9 modifiers:0 client:mockClient];
                [controller inputText:@"4" key:kVK_ANSI_Keypad4 modifiers:0 client:mockClient];
                
                [[mockController expect] beep];
                BOOL handled = [controller inputText:@"9" key:kVK_ANSI_Keypad4 modifiers:0 client:mockClient];
                expect(handled).to.beTruthy();
                expect([[mockBuffer inputBuffer] length]).to.equal(6);
                [mockController verify];
            });
        });

        describe(@"decimal key", ^{            
            it(@"should enter selection mode", ^{
                [[[mockBuffer expect] andForwardToRealObject] appendBuffer:@"8"];
                [[[mockBuffer expect] andForwardToRealObject] appendBuffer:@"."];
                [controller inputText:@"8" key:kVK_ANSI_Keypad8 modifiers:0 client:mockClient];
                [controller inputText:@"." key:kVK_ANSI_KeypadDecimal modifiers:0 client:mockClient];
                [mockBuffer verify];
                expect(controller.buffer.selectionMode).to.beTruthy();
            });

            it(@"should select candidate", ^{
                [[[mockBuffer expect] andForwardToRealObject] appendBuffer:@"8"];
                [[[mockBuffer expect] andForwardToRealObject] appendBuffer:@"."];
                [((BSMBuffer*)[[mockBuffer expect] andForwardToRealObject]) setSelectedIndex:7U];
                [controller inputText:@"8" key:kVK_ANSI_Keypad8 modifiers:0 client:mockClient];
                [controller inputText:@"." key:kVK_ANSI_KeypadDecimal modifiers:0 client:mockClient];
                [controller inputText:@"8" key:kVK_ANSI_Keypad8 modifiers:0 client:mockClient];
                [mockBuffer verify];
                
                [[[mockBuffer expect] andForwardToRealObject] appendBuffer:@"8"];
                [[[mockBuffer expect] andForwardToRealObject] appendBuffer:@"."];
                [((BSMBuffer*)[[mockBuffer expect] andForwardToRealObject]) setSelectedIndex:0U];
                [controller inputText:@"8" key:kVK_ANSI_Keypad8 modifiers:0 client:mockClient];
                [controller inputText:@"." key:kVK_ANSI_KeypadDecimal modifiers:0 client:mockClient];
                [controller inputText:@"1" key:kVK_ANSI_Keypad1 modifiers:0 client:mockClient];
                [mockBuffer verify];
            });
        });


    });
});

SpecEnd