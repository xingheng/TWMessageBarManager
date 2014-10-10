//
//  TWMessageBarManager.m
//
//  Created by Terry Worona on 5/13/13.
//  Copyright (c) 2013 Terry Worona. All rights reserved.
//

#import "TWMessageBarManager.h"

// Quartz
#import <QuartzCore/QuartzCore.h>

// Numerics (TWMessageBarStyleSheet)
CGFloat const kTWMessageBarStyleSheetMessageBarAlpha = 0.96f;

// Numerics (TWMessageView)
CGFloat const kTWMessageViewBarPadding = 5.0f;
CGFloat const kTWMessageViewIconSize = 18.0f;
CGFloat const kTWMessageViewTextOffset = 2.0f;
NSUInteger const kTWMessageViewiOS7Identifier = 7;

// Numerics (TWMessageBarManager)
CGFloat const kTWMessageBarManagerDisplayDelay = 3.0f;
CGFloat const kTWMessageBarManagerDismissAnimationDuration = 0.25f;
CGFloat const kTWMessageBarManagerPanVelocity = 0.2f;
CGFloat const kTWMessageBarManagerPanAnimationDuration = 0.0002f;

// Strings (TWMessageBarStyleSheet)
NSString * const kTWMessageBarStyleSheetImageIconError = @"icon-error.png";
NSString * const kTWMessageBarStyleSheetImageIconSuccess = @"icon-success.png";
NSString * const kTWMessageBarStyleSheetImageIconInfo = @"icon-info.png";

// Fonts (TWMessageView)
static UIFont *kTWMessageViewTitleFont = nil;

// Colors (TWMessageView)
static UIColor *kTWMessageViewTitleColor = nil;

// Colors (TWDefaultMessageBarStyleSheet)
static UIColor *kTWDefaultMessageBarStyleSheetErrorBackgroundColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetSuccessBackgroundColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetInfoBackgroundColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetErrorStrokeColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetSuccessStrokeColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetInfoStrokeColor = nil;

@protocol TWMessageViewDelegate;

@interface TWMessageView : UIView

@property (nonatomic, copy) NSString *titleString;

@property (nonatomic, assign) TWMessageBarMessageType messageType;

@property (nonatomic, assign) BOOL hasCallback;
@property (nonatomic, strong) NSArray *callbacks;

@property (nonatomic, assign, getter = isHit) BOOL hit;

@property (nonatomic, assign) CGFloat duration;

@property (nonatomic, assign) UIStatusBarStyle statusBarStyle;
@property (nonatomic, assign) BOOL statusBarHidden;

@property (nonatomic, weak) id <TWMessageViewDelegate> delegate;

// Initializers
- (id)initWithTitle:(NSString *)title type:(TWMessageBarMessageType)type;

// Getters
- (CGFloat)height;
- (CGFloat)width;
- (CGFloat)statusBarOffset;
- (CGFloat)availableWidth;
- (CGSize)titleSize;
- (CGRect)statusBarFrame;
- (UIFont *)titleFont;
- (UIColor *)titleColor;

// Helpers
- (CGRect)orientFrame:(CGRect)frame;

// Notifications
- (void)didChangeDeviceOrientation:(NSNotification *)notification;

@end

@protocol TWMessageViewDelegate <NSObject>

- (NSObject<TWMessageBarStyleSheet> *)styleSheetForMessageView:(TWMessageView *)messageView;

@end

@interface TWDefaultMessageBarStyleSheet : NSObject <TWMessageBarStyleSheet>

+ (TWDefaultMessageBarStyleSheet *)styleSheet;

@end

@interface TWMessageWindow : UIWindow

@end

@interface TWMessageBarViewController : UIViewController

@property (nonatomic, assign) UIStatusBarStyle statusBarStyle;
@property (nonatomic, assign) BOOL statusBarHidden;

@end

@interface TWMessageBarManager () <TWMessageViewDelegate>

@property (nonatomic, strong) NSMutableArray *messageBarQueue;
@property (nonatomic, assign, getter = isMessageVisible) BOOL messageVisible;
@property (nonatomic, strong) TWMessageWindow *messageWindow;
@property (nonatomic, readwrite) NSArray *accessibleElements; // accessibility

// Static
+ (CGFloat)durationForMessageType:(TWMessageBarMessageType)messageType;

// Helpers
- (void)showNextMessage;
- (void)generateAccessibleElementWithTitle:(NSString *)title;

// Gestures
- (void)itemSelected:(UITapGestureRecognizer *)recognizer;

// Getters
- (UIView *)messageWindowView;
- (TWMessageBarViewController *)messageBarViewController;

// Master presetation
- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type duration:(CGFloat)duration statusBarHidden:(BOOL)statusBarHidden statusBarStyle:(UIStatusBarStyle)statusBarStyle callback:(void (^)())callback;

@end

@implementation TWMessageBarManager

#pragma mark - Singleton

+ (TWMessageBarManager *)sharedInstance
{
    static dispatch_once_t pred;
    static TWMessageBarManager *instance = nil;
    dispatch_once(&pred, ^{
        instance = [[self alloc] init];
    });
	return instance;
}

#pragma mark - Static

+ (CGFloat)defaultDuration
{
    return kTWMessageBarManagerDisplayDelay;
}

+ (CGFloat)durationForMessageType:(TWMessageBarMessageType)messageType
{
    return kTWMessageBarManagerDisplayDelay;
}

#pragma mark - Alloc/Init

- (id)init
{
    self = [super init];
    if (self)
    {
        _messageBarQueue = [[NSMutableArray alloc] init];
        _messageVisible = NO;
        _styleSheet = [TWDefaultMessageBarStyleSheet styleSheet];
    }
    return self;
}

#pragma mark - Public

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type
{
    [self showMessageWithTitle:title type:type duration:[TWMessageBarManager durationForMessageType:type] callback:nil];
}

- (void)showMessageWithTitle:(NSString *)title  type:(TWMessageBarMessageType)type callback:(void (^)())callback
{
    [self showMessageWithTitle:title type:type duration:[TWMessageBarManager durationForMessageType:type] callback:callback];
}

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type duration:(CGFloat)duration
{
    [self showMessageWithTitle:title type:type duration:duration callback:nil];
}

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type duration:(CGFloat)duration callback:(void (^)())callback
{
    [self showMessageWithTitle:title type:type duration:duration statusBarStyle:UIStatusBarStyleDefault callback:callback];
}

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type statusBarStyle:(UIStatusBarStyle)statusBarStyle callback:(void (^)())callback
{
    [self showMessageWithTitle:title type:type duration:kTWMessageBarManagerDisplayDelay statusBarStyle:statusBarStyle callback:callback];
}

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type duration:(CGFloat)duration statusBarStyle:(UIStatusBarStyle)statusBarStyle callback:(void (^)())callback
{
    [self showMessageWithTitle:title type:type duration:duration statusBarHidden:NO statusBarStyle:statusBarStyle callback:callback];
}

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type statusBarHidden:(BOOL)statusBarHidden callback:(void (^)())callback
{
    [self showMessageWithTitle:title type:type duration:[TWMessageBarManager durationForMessageType:type] statusBarHidden:statusBarHidden statusBarStyle:UIStatusBarStyleDefault callback:callback];
}

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type duration:(CGFloat)duration statusBarHidden:(BOOL)statusBarHidden callback:(void (^)())callback
{
    [self showMessageWithTitle:title type:type duration:duration statusBarHidden:statusBarHidden statusBarStyle:UIStatusBarStyleDefault callback:callback];
}

#pragma mark - Master Presentation

- (void)showMessageWithTitle:(NSString *)title type:(TWMessageBarMessageType)type duration:(CGFloat)duration statusBarHidden:(BOOL)statusBarHidden statusBarStyle:(UIStatusBarStyle)statusBarStyle callback:(void (^)())callback
{
    // check the current title whether exists in global messsage queue, drop it if it does.
    for (id itemView in self.messageBarQueue) {
        TWMessageView *msgView = nil;
        if ([itemView isKindOfClass:[UIView class]]) {
            NSArray *subViews = [itemView subviews];
            if (subViews != nil && subViews.count > 0) {
                msgView = subViews[0];
            }
        }
        else if ([itemView isKindOfClass:[TWMessageView class]]) {
            msgView = (TWMessageView *)itemView;
        }
        
        if (msgView != nil && [msgView.titleString isEqualToString:title]) {
            return;
        }
    }
    
    TWMessageView *messageView = [[TWMessageView alloc] initWithTitle:title type:type];
    messageView.delegate = self;
    
    messageView.callbacks = callback ? [NSArray arrayWithObject:callback] : [NSArray array];
    messageView.hasCallback = callback ? YES : NO;
    
    messageView.duration = duration;
    messageView.hidden = YES;
    
    messageView.statusBarStyle = statusBarStyle;
    messageView.statusBarHidden = statusBarHidden;
    
    UIView *containerView = [[UIView alloc] initWithFrame:messageView.frame];
    containerView.backgroundColor = [UIColor clearColor];
    containerView.clipsToBounds = YES;
    [containerView addSubview:messageView];
    
    [[self messageWindowView] addSubview:containerView];
    [[self messageWindowView] bringSubviewToFront:containerView];
    
    [self.messageBarQueue addObject:containerView];
    
    if (!self.messageVisible)
    {
        [self showNextMessage];
    }
}

- (void)hideAllAnimated:(BOOL)animated
{
    for (UIView *subview in [[self messageWindowView] subviews])
    {
        if ([subview isKindOfClass:[TWMessageView class]])
        {
            TWMessageView *currentMessageView = (TWMessageView *)subview;
            if (animated)
            {
                [UIView animateWithDuration:kTWMessageBarManagerDismissAnimationDuration animations:^{
                    currentMessageView.center = CGPointMake(currentMessageView.center.x, currentMessageView.center.y - currentMessageView.frame.size.height); // slide back up
                } completion:^(BOOL finished) {
                    [currentMessageView removeFromSuperview];
                }];
            }
            else
            {
                [currentMessageView removeFromSuperview];
            }
        }
    }
    
    self.messageVisible = NO;
    [self.messageBarQueue removeAllObjects];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)hideAll
{
    [self hideAllAnimated:NO];
}

#pragma mark - Helpers

- (void)showNextMessage
{
    if ([self.messageBarQueue count] > 0)
    {
        self.messageVisible = YES;
        
        UIView *containerView = [self.messageBarQueue objectAtIndex:0];
        
        TWMessageView *messageView = [containerView.subviews objectAtIndex:0];
        [self messageBarViewController].statusBarHidden = messageView.statusBarHidden; // important to do this prior to hiding
        
        [containerView setFrame:CGRectMake(0, 64, [messageView width], [messageView height])];
        [messageView setFrame:CGRectMake(0, 0, [messageView width], [messageView height])];
        
        messageView.hidden = NO;
        [messageView setNeedsDisplay];
        
        UITapGestureRecognizer *gest = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(itemSelected:)];
        [messageView addGestureRecognizer:gest];
        
        if (messageView)
        {
            [self messageBarViewController].statusBarStyle = messageView.statusBarStyle;
            CGPoint downPoint = messageView.center;
            messageView.center = CGPointMake(messageView.center.x, messageView.center.y - messageView.frame.size.height);
            
            [UIView animateWithDuration:kTWMessageBarManagerDismissAnimationDuration animations:^{
                messageView.center = downPoint;// slide down
            }];
            [self performSelector:@selector(itemSelected:) withObject:containerView afterDelay:messageView.duration];
            
            [self generateAccessibleElementWithTitle:messageView.titleString];
        }
    }
}

- (void)generateAccessibleElementWithTitle:(NSString *)title
{
    UIAccessibilityElement *textElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
    textElement.accessibilityLabel = [NSString stringWithFormat:@"%@", title];
    textElement.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.accessibleElements = @[textElement];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self); // notify the accessibility framework to read the message
}

#pragma mark - Gestures

- (void)itemSelected:(id)sender
{
    TWMessageView *messageView = nil;
    BOOL itemHit = NO;
    
    if ([sender isKindOfClass:[UIGestureRecognizer class]])
    {
        UIView *senderView = ((UIGestureRecognizer *)sender).view;
        
        if ([senderView isKindOfClass:[TWMessageView class]])
            messageView = (TWMessageView *)senderView;
        else if ([[senderView subviews] count] > 0)
        {
            messageView = [senderView subviews][0];
        }
        itemHit = YES;
    }
    else if ([sender isKindOfClass:[TWMessageView class]])
    {
        messageView = (TWMessageView *)sender;
    }
    else if ([sender isKindOfClass:[UIView class]])
    {
        if ([[(UIView *)sender subviews] count] > 0)
        {
            messageView = [(UIView *)sender subviews][0];
        }
    }
    
    if (messageView != nil)
        [self.messageBarQueue removeObject:messageView.superview];
    
    
    if (messageView && ![messageView isHit])
    {
        messageView.hit = YES;
        
        [UIView animateWithDuration:kTWMessageBarManagerDismissAnimationDuration animations:^{
            messageView.center = CGPointMake(messageView.center.x, messageView.center.y - messageView.frame.size.height); // slide back up
        } completion:^(BOOL finished) {
            self.messageVisible = NO;
            
            if ([messageView isKindOfClass:[TWMessageView class]])
            {
                [messageView removeFromSuperview];
                [messageView.superview removeFromSuperview];
            }
            else
                [messageView removeFromSuperview];
            
            if (itemHit)
            {
                if ([messageView.callbacks count] > 0)
                {
                    id obj = [messageView.callbacks objectAtIndex:0];
                    if (![obj isEqual:[NSNull null]])
                    {
                        ((void (^)())obj)();
                    }
                }
            }
            
            if([self.messageBarQueue count] > 0)
            {
                [self showNextMessage];
            }
            else
            {
                self.messageWindow = nil;
            }
        }];
    }
}

#pragma mark - Getters

- (UIView *)messageWindowView
{
    return [self messageBarViewController].view;
}

- (TWMessageBarViewController *)messageBarViewController
{
    if (!self.messageWindow)
    {
        self.messageWindow = [[TWMessageWindow alloc] init];
        self.messageWindow.frame = [UIApplication sharedApplication].keyWindow.frame;
        self.messageWindow.hidden = NO;
        self.messageWindow.windowLevel = UIWindowLevelNormal;
        self.messageWindow.backgroundColor = [UIColor clearColor];
        self.messageWindow.rootViewController = [[TWMessageBarViewController alloc] init];
    }
    return (TWMessageBarViewController *)self.messageWindow.rootViewController;
}

- (NSArray *)accessibleElements
{
    if (_accessibleElements != nil)
    {
        return _accessibleElements;
    }
    _accessibleElements = [NSArray array];
    return _accessibleElements;
}

#pragma mark - Setters

- (void)setStyleSheet:(NSObject<TWMessageBarStyleSheet> *)styleSheet
{
    if (styleSheet != nil)
    {
        _styleSheet = styleSheet;
    }
}

#pragma mark - TWMessageViewDelegate

- (NSObject<TWMessageBarStyleSheet> *)styleSheetForMessageView:(TWMessageView *)messageView
{
    return self.styleSheet;
}

#pragma mark - UIAccessibilityContainer

- (NSInteger)accessibilityElementCount
{
    return (NSInteger)[self.accessibleElements count];
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
    return [self.accessibleElements objectAtIndex:(NSUInteger)index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
    return (NSInteger)[self.accessibleElements indexOfObject:element];
}

- (BOOL)isAccessibilityElement
{
    return NO;
}

@end

@implementation TWMessageView

#pragma mark - Alloc/Init

+ (void)initialize
{
	if (self == [TWMessageView class])
	{
        // Fonts
        kTWMessageViewTitleFont = [UIFont boldSystemFontOfSize:18.0];
        
        // Colors
        kTWMessageViewTitleColor = [UIColor colorWithWhite:1.0 alpha:1.0];
	}
}

- (id)initWithTitle:(NSString *)title type:(TWMessageBarMessageType)type
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
        self.userInteractionEnabled = YES;
        
        _titleString = title;
        _messageType = type;
        
        _hasCallback = NO;
        _hit = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeDeviceOrientation:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

#pragma mark - Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if ([self.delegate respondsToSelector:@selector(styleSheetForMessageView:)])
    {
        id<TWMessageBarStyleSheet> styleSheet = [self.delegate styleSheetForMessageView:self];
        
        // background fill
        CGContextSaveGState(context);
        {
            if ([styleSheet respondsToSelector:@selector(backgroundColorForMessageType:)])
            {
                [[styleSheet backgroundColorForMessageType:self.messageType] set];
                CGContextFillRect(context, rect);
            }
        }
        CGContextRestoreGState(context);
        
        // bottom stroke
        CGContextSaveGState(context);
        {
            if ([styleSheet respondsToSelector:@selector(strokeColorForMessageType:)])
            {
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, 0, rect.size.height);
                CGContextSetStrokeColorWithColor(context, [styleSheet strokeColorForMessageType:self.messageType].CGColor);
                CGContextSetLineWidth(context, 1.0);
                CGContextAddLineToPoint(context, rect.size.width, rect.size.height);
                CGContextStrokePath(context);
            }
        }
        CGContextRestoreGState(context);
        
        CGSize titleLabelSize = [self titleSize];
        CGFloat paddingWidth = kTWMessageViewBarPadding * 1.5;
        
        CGFloat xOffset = (rect.size.width - titleLabelSize.width - kTWMessageViewIconSize - paddingWidth) / 2;//kTWMessageViewBarPadding;
        CGFloat yOffset = kTWMessageViewBarPadding + kTWMessageViewTextOffset;
        
        // icon
        CGContextSaveGState(context);
        {
            if ([styleSheet respondsToSelector:@selector(iconImageForMessageType:)])
            {
                [[styleSheet iconImageForMessageType:self.messageType] drawInRect:CGRectMake(xOffset, yOffset, kTWMessageViewIconSize, kTWMessageViewIconSize)];
            }
        }
        CGContextRestoreGState(context);
        
        //xOffset += kTWMessageViewIconSize + kTWMessageViewBarPadding;
        xOffset += kTWMessageViewIconSize + paddingWidth;
        
        if (self.titleString)
        {
            yOffset = ceil(rect.size.height * 0.5) - ceil(titleLabelSize.height * 0.5);// - kTWMessageViewTextOffset;
        }
        
        if ([[UIDevice currentDevice] isRunningiOS7OrLater])
        {
            NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            paragraphStyle.alignment = NSTextAlignmentLeft;
            
            [[self titleColor] set];
            
            [self.titleString drawWithRect:CGRectMake(xOffset, yOffset, titleLabelSize.width, titleLabelSize.height)
                                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                                attributes:@{NSFontAttributeName:[self titleFont], NSForegroundColorAttributeName:[self titleColor], NSParagraphStyleAttributeName:paragraphStyle}
                                   context:nil];
        }
        else
        {
            [[self titleColor] set];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [self.titleString drawInRect:CGRectMake(xOffset, yOffset, titleLabelSize.width, titleLabelSize.height) withFont:[self titleFont] lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
#pragma clang diagnostic pop
        }
    }
}

#define kPhantomMessageViewBarPadding       (kTWMessageViewBarPadding * 2)

#pragma mark - Getters

- (CGFloat)height
{
    CGSize titleLabelSize = [self titleSize];
    return kPhantomMessageViewBarPadding + MAX(titleLabelSize.height, kTWMessageViewIconSize);
}

- (CGFloat)width
{
    return [self statusBarFrame].size.width;
}

- (CGFloat)statusBarOffset
{
    return [[UIDevice currentDevice] isRunningiOS7OrLater] ? [self statusBarFrame].size.height : 0.0;
}

- (CGFloat)availableWidth
{
    return ([self width] - kPhantomMessageViewBarPadding - 20);
}

- (CGSize)titleSize
{
    CGSize boundedSize = CGSizeMake([self availableWidth], CGFLOAT_MAX);
    CGSize titleLabelSize;
    
    if ([[UIDevice currentDevice] isRunningiOS7OrLater])
    {
        NSDictionary *titleStringAttributes = [NSDictionary dictionaryWithObject:[self titleFont] forKey: NSFontAttributeName];
        titleLabelSize = [self.titleString boundingRectWithSize:boundedSize
                                                        options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin
                                                     attributes:titleStringAttributes
                                                        context:nil].size;
    }
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        titleLabelSize = [_titleString sizeWithFont:[self titleFont] constrainedToSize:boundedSize lineBreakMode:NSLineBreakByTruncatingTail];
#pragma clang diagnostic pop
    }
    
    return CGSizeMake(ceilf(titleLabelSize.width), ceilf(titleLabelSize.height));
}

- (CGRect)statusBarFrame
{
    CGRect windowFrame = [self orientFrame:[UIApplication sharedApplication].keyWindow.frame];
    CGRect statusFrame = [self orientFrame:[UIApplication sharedApplication].statusBarFrame];
    return CGRectMake(windowFrame.origin.x, windowFrame.origin.y, windowFrame.size.width, statusFrame.size.height);
}

- (UIFont *)titleFont
{
    if ([self.delegate respondsToSelector:@selector(styleSheetForMessageView:)])
    {
        id<TWMessageBarStyleSheet> styleSheet = [self.delegate styleSheetForMessageView:self];
        if ([styleSheet respondsToSelector:@selector(titleFontForMessageType:)])
        {
            return [styleSheet titleFontForMessageType:self.messageType];
        }
    }
    return kTWMessageViewTitleFont;
}

- (UIColor *)titleColor
{
    if ([self.delegate respondsToSelector:@selector(styleSheetForMessageView:)])
    {
        id<TWMessageBarStyleSheet> styleSheet = [self.delegate styleSheetForMessageView:self];
        if ([styleSheet respondsToSelector:@selector(titleColorForMessageType:)])
        {
            return [styleSheet titleColorForMessageType:self.messageType];
        }
    }
    return kTWMessageViewTitleColor;
}

#pragma mark - Helpers

- (CGRect)orientFrame:(CGRect)frame
{
    if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) || UIDeviceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
    {
        frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.width);
    }
    return frame;
}

#pragma mark - Notifications

- (void)didChangeDeviceOrientation:(NSNotification *)notification
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, [self statusBarFrame].size.width, self.frame.size.height);
    [self setNeedsDisplay];
}

@end

@implementation TWDefaultMessageBarStyleSheet

#pragma mark - Alloc/Init

+ (void)initialize
{
	if (self == [TWDefaultMessageBarStyleSheet class])
	{
        // Colors (background)
        kTWDefaultMessageBarStyleSheetErrorBackgroundColor = [UIColor colorWithRed:1.0 green:0.611 blue:0.0 alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // orange
        kTWDefaultMessageBarStyleSheetSuccessBackgroundColor = [UIColor colorWithRed:0.0f green:0.831f blue:0.176f alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // green
        kTWDefaultMessageBarStyleSheetInfoBackgroundColor = [UIColor colorWithRed:0.0 green:0.482 blue:1.0 alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // blue
        
        // Colors (stroke)
        kTWDefaultMessageBarStyleSheetErrorStrokeColor = [UIColor colorWithRed:0.949f green:0.580f blue:0.0f alpha:1.0f]; // orange
        kTWDefaultMessageBarStyleSheetSuccessStrokeColor = [UIColor colorWithRed:0.0f green:0.772f blue:0.164f alpha:1.0f]; // green
        kTWDefaultMessageBarStyleSheetInfoStrokeColor = [UIColor colorWithRed:0.0f green:0.415f blue:0.803f alpha:1.0f]; // blue
    }
}

+ (TWDefaultMessageBarStyleSheet *)styleSheet
{
    return [[TWDefaultMessageBarStyleSheet alloc] init];
}

#pragma mark - TWMessageBarStyleSheet

- (UIColor *)backgroundColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *backgroundColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            backgroundColor = kTWDefaultMessageBarStyleSheetErrorBackgroundColor;
            break;
        case TWMessageBarMessageTypeSuccess:
            backgroundColor = kTWDefaultMessageBarStyleSheetSuccessBackgroundColor;
            break;
        case TWMessageBarMessageTypeInfo:
            backgroundColor = kTWDefaultMessageBarStyleSheetInfoBackgroundColor;
            break;
        default:
            break;
    }
    return backgroundColor;
}

- (UIColor *)strokeColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *strokeColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            strokeColor = kTWDefaultMessageBarStyleSheetErrorStrokeColor;
            break;
        case TWMessageBarMessageTypeSuccess:
            strokeColor = kTWDefaultMessageBarStyleSheetSuccessStrokeColor;
            break;
        case TWMessageBarMessageTypeInfo:
            strokeColor = kTWDefaultMessageBarStyleSheetInfoStrokeColor;
            break;
        default:
            break;
    }
    return strokeColor;
}

- (UIImage *)iconImageForMessageType:(TWMessageBarMessageType)type
{
    UIImage *iconImage = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconError];
            break;
        case TWMessageBarMessageTypeSuccess:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconSuccess];
            break;
        case TWMessageBarMessageTypeInfo:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconInfo];
            break;
        default:
            break;
    }
    return iconImage;
}

@end

@implementation TWMessageWindow

#pragma mark - Touches

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitView = [super hitTest:point withEvent:event];
    
    /*
     * Pass touches through if they land on the rootViewController's view.
     * Allows notification interaction without blocking the window below.
     */
    if ([hitView isEqual: self.rootViewController.view])
    {
        hitView = nil;
    }
    
    return hitView;
}

@end

@implementation UIDevice (Additions)

#pragma mark - OS Helpers

- (BOOL)isRunningiOS7OrLater
{
    NSString *systemVersion = self.systemVersion;
    NSUInteger systemInt = [systemVersion intValue];
    return systemInt >= kTWMessageViewiOS7Identifier;
}

@end

@implementation TWMessageBarViewController

#pragma mark - Setters

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle
{
    _statusBarStyle = statusBarStyle;
    
    if ([[UIDevice currentDevice] isRunningiOS7OrLater])
    {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (void)setStatusBarHidden:(BOOL)statusBarHidden
{
    _statusBarHidden = statusBarHidden;

    if ([[UIDevice currentDevice] isRunningiOS7OrLater])
    {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.statusBarStyle;
}

- (BOOL)prefersStatusBarHidden
{
    return self.statusBarHidden;
}

@end
