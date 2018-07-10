### 1、Operation Queues简介

Operation Queues是对GCD的封装，提供面向对象的API，实现多线程的解决方案。主要提供```NSOperation```(操作)和```NSOperationQueue```(操作队列)。

1. **NSOperation**
- 在线程中所要执行的代码段。
- 操作队列所调度的任务。
- 可以添加依赖关系和优先级。
- 可以通过KVO观察执行状态。
- 我们使用 **NSOperation** 子类 **NSInvocationOperation**、**NSBlockOperation**，或者**自定义**子类来封装操作。
2. **NSOperationQueue**
- 用来存放操作的队列。是由GCD提供的一个队列模型的Cocoa抽象。GCD提供了更加底层的控制，而操作队列则在GCD之上实现了一些方便的功能。
- NSOperationQueue操作队列中的任务的执行顺序收到任务的isReady【就绪状态】状态和任务的队列优先级影响。这和GCD中的队列FIFO的执行顺序有很大区别。
- 通过设置NSOperationQueue的最大并发操作数(maxConcurrentOperationCount)来控制任务执行是并发还是串行。
- NSOperationQueue有两种不通类型的队列:主队列和自定义队列。主队列在主线程上运行，而自定义队列在后台执行。这两种队列中加入的任务都需要用NSOperation的子类来表示。

### 3、NSOperationQueue
- 主队列： 凡是添加到主队列中的操作，都会放到主线程中执行。串行执行。</br>
```NSOperationQueue *queue = [NSOperationQueue mainQueue];```
- 自定义队列：添加到这种队列中的操作，就会自动放到子线程中执行。具有串行和并发功能。</br>
```NSOperationQueue *queue = [[NSOperationQueue alloc] init];```
- 添加任务：创建任务后，添加到队列执行</br>
```- (void)addOperation:(NSOperation *)op;```
- 直接添加任务：直接通过block添加任务到队列</br>
```- (void)addOperationWithBlock:(void (^)(void))block;```
- 控制串行执行、并发执行: 使用```maxConcurrentOperationCount```控制串行和并发。</br>
默认情况下为-1，表示不进行限制，可进行并发执行。</br>
为1时，队列为串行队列。</br>
只能串行执行。大于1时，队列为并发队列。

```objc
#pragma mark - NSOperationQueue
- (void)operationQueueTest {
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 2;
    
    [queue addOperationWithBlock:^{
        [self myTask1];
    }];
    
    [queue addOperationWithBlock:^{
        [self myTask2];
    }];
    
    [queue addOperationWithBlock:^{
        [self myTask3];
    }];
    
}

- (void)addToMainQueue {
    
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    NSInvocationOperation *op1 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(myTask1) object:nil];
    NSInvocationOperation *op2 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(myTask2) object:nil];
    NSBlockOperation *op3 = [NSBlockOperation blockOperationWithBlock:^{
        [self myTask3];
    }];
    
    
    [mainQueue addOperation:op1];
    [mainQueue addOperation:op2];
    [mainQueue addOperation:op3];
    
}

- (void)addToCustomQueue {
    
    NSOperationQueue *customQueue = [[NSOperationQueue alloc] init];
//    customQueue.maxConcurrentOperationCount = 3;
//    customQueue.maxConcurrentOperationCount = 2;
    
    NSInvocationOperation *op1 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(myTask1) object:nil];
    NSInvocationOperation *op2 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(myTask2) object:nil];
    NSBlockOperation *op3 = [NSBlockOperation blockOperationWithBlock:^{
        [self myTask3];
    }];
    
    [op1 addDependency:op3];
    [customQueue addOperation:op1];
    [customQueue addOperation:op2];
    [customQueue addOperation:op3];
    
}

#pragma mark - tasks
- (void)myTask1 {
    NSLog(@"执行Operation:%@", [NSThread currentThread]);
    for (NSInteger i = 0; i < 10; i++) {
        NSLog(@"task1---%ld---%@", i, [NSThread currentThread]);
    }
}

- (void)myTask2 {
    NSLog(@"执行Operation:%@", [NSThread currentThread]);
    for (NSInteger i = 0; i < 10; i++) {
        NSLog(@"task2---%ld---%@", i, [NSThread currentThread]);
    }
}

- (void)myTask3 {
    NSLog(@"执行Operation:%@", [NSThread currentThread]);
    for (NSInteger i = 0; i < 10; i++) {
        NSLog(@"task3---%ld---%@", i, [NSThread currentThread]);
    }
}
```

### 4、NSOperation
可以创建NSOperation子类后手动开启执行。也可以添加到队列中，让队列对任务进行管理。
- 添加依赖：当依赖的任务执行完成后才会执行。</br>
```- (void)addDependency:(NSOperation *)op;```
- 移除依赖: 取消当前任务对 op 的依赖。</br>
```- (void)removeDependency:(NSOperation *)op;```
- 优先级: NSOperation 提供了```queuePriority```（优先级）属性。
```objc
// 优先级的取值
typedef NS_ENUM(NSInteger, NSOperationQueuePriority) {
    NSOperationQueuePriorityVeryLow = -8L,
    NSOperationQueuePriorityLow = -4L,
    NSOperationQueuePriorityNormal = 0,
    NSOperationQueuePriorityHigh = 4,
    NSOperationQueuePriorityVeryHigh = 8
};
```
> 对于添加到队列中的操作，首先进入准备就绪的状态（就绪状态取决于操作之间的依赖关系），然后进入就绪状态的操作的开始执行顺序（非结束执行顺序）由操作之间相对的优先级决定（优先级是操作对象自身的属性）。

#### NSInvocationOperation
```objc
#pragma mark - NSInvocationOperation
- (void)invocationOperationCreate {
    
    NSLog(@"创建Operation:%@", [NSThread currentThread]);
    
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(myTask1) object:nil];
    
    [op start];
    
}

- (void)invocationOperationAtNewThread {
    //在新线程中执行
    [NSThread detachNewThreadSelector:@selector(invocationOperationCreate) toTarget:self withObject:nil];
}
```
#### NSBlockOperation
```objc
#pragma mark - NSBlockOperation
- (void)blockOperationCreate {
    
    NSLog(@"创建Operation:%@", [NSThread currentThread]);
    
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        [self myTask1];
    }];
    
    //新添加的任务，不在本线程执行，将开启新线程并发执行
    [op addExecutionBlock:^{
        [self myTask1];
    }];
    
    [op addExecutionBlock:^{
        [self myTask1];
    }];
    
    [op start];
}

- (void)blockOperationAtNewThread {
    [NSThread detachNewThreadSelector:@selector(blockOperationCreate) toTarget:self withObject:nil];
}

```
#### 自定义NSOperation
可以通过重写 main 或者 start 方法 来定义自己的 NSOperation 对象。重写main方法比较简单，我们不需要管理操作的状态属性  isExecuting 和 isFinished。当 main 执行完返回的时候，这个操作就结束了。如果重写start方法，需要自己管理状态，以便队列管理任务。
```objc
#import <Foundation/Foundation.h>

@interface CustomOperation : NSOperation

@end

#import "CustomOperation.h"

@implementation CustomOperation

- (void)main {
    NSLog(@"执行Operation:%@", [NSThread currentThread]);
    for (NSInteger i = 0; i < 10; i++) {
        NSLog(@"---%ld---%@", i, [NSThread currentThread]);
    }
}

@end
```
```objc
#pragma mark - CustomOperation
- (void)customOperationCreate {
    
    CustomOperation *op = [[CustomOperation alloc] init];
    
    [op start];
}

- (void)customOperationAtNewThread {
    [NSThread detachNewThreadSelector:@selector(customOperationCreate) toTarget:self withObject:nil];
}
```

### 5、NSOperation、NSOperationQueue 线程间的通信
一般在主线程里边进行 UI 刷新，耗时操作放在子线程。
通过线程间的通信，先在其他线程中执行操作，等操作执行完了之后再回到主线程执行主线程的相应操作。
```objc
/**
 * 线程间通信
 */
- (void)communication {

    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc]init];

    // 2.添加操作
    [queue addOperationWithBlock:^{
        // 异步进行耗时操作
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }

        // 回到主线程
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // 进行一些 UI 刷新等操作
            for (int i = 0; i < 2; i++) {
                [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
                NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
            }
        }];
    }];
}
```
### 6、NSOperation、NSOperationQueue 线程同步和线程安全
通过线程加锁，实现线程的安全。如@synchronized、 NSLock、NSRecursiveLock、NSCondition、NSConditionLock、pthread_mutex、dispatch_semaphore、OSSpinLock、atomic(property) set/ge等等各种方式。

> 参考
>- [https://www.jianshu.com/p/4443d668e931](https://www.jianshu.com/p/4443d668e931)
>- [https://www.jianshu.com/p/4b1d77054b35](https://www.jianshu.com/p/4b1d77054b35)
>- [http://blog.leichunfeng.com/blog/2015/07/29/ios-concurrency-programming-operation-queues/](http://blog.leichunfeng.com/blog/2015/07/29/ios-concurrency-programming-operation-queues/)