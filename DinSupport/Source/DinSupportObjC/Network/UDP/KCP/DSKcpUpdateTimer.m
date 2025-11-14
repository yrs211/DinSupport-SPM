//
//  DSKcpUpdateTimer.m
//  DinsaferIPC
//
//  Created by Jin on 2020/9/3.
//  Copyright © 2020 Dinsafer. All rights reserved.
//

#import "DSKcpUpdateTimer.h"

typedef enum : NSUInteger {
    DSKcpUpdateTimerStateSuspended,
    DSKcpUpdateTimerStateResumed,
} DSKcpUpdateTimerState;

@interface DSKcpUpdateTimer()

@property (nonatomic, strong) dispatch_queue_t timerQueue;
@property (nonatomic, strong) dispatch_source_t updateKcpTimer;
@property (nonatomic, assign) DSKcpUpdateTimerState state;

@end

@implementation DSKcpUpdateTimer

- (void)dealloc {
    dispatch_source_set_event_handler(_updateKcpTimer, NULL);
    dispatch_source_cancel(_updateKcpTimer);
    [self resume];
    _updateKcpTimer = nil;
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue exitcute:(dispatch_block_t _Nullable)handler {
    self = [super init];
    if (self) {
        _timerQueue = queue;
        _updateKcpTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _timerQueue);
        dispatch_source_set_timer(_updateKcpTimer, DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(_updateKcpTimer, handler);
    }
    return self;
}

- (void)resume {
    if (_state == DSKcpUpdateTimerStateResumed) {
        return;
    }
    _state = DSKcpUpdateTimerStateResumed;
    dispatch_resume(_updateKcpTimer);
}

- (void)suspend {
    if (_state == DSKcpUpdateTimerStateSuspended) {
        return;
    }
    _state = DSKcpUpdateTimerStateSuspended;
    dispatch_suspend(_updateKcpTimer);
}

@end
