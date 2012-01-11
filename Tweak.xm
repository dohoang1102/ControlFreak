#import "UIEvent+Synthesize.h"
#import "UITouch+Synthesize.h"
#import "GSEvent.h"
#import <substrate.h>

typedef enum {
	UP,
	DOWN,
	LEFT,
	RIGHT,
	X,
	A,
	B,
	Y,
	L,
	R,
	START,
	SELECT
} iCPButton;

typedef enum {
	PRESS,
	RELEASE
} iCPButtonState;

static NSString* presses = @"wxadlkoihjuy";
#import <SpringBoard5/SBApplication.h>

static NSString* releases = @"ezqcvpgmrnft";
static NSMutableDictionary* touches = [[NSMutableDictionary alloc] init];
static NSDictionary* prefs = [[[NSDictionary alloc] initWithContentsOfFile:@"/Library/Application Support/ControlFreak/com.sega.soniccd.plist"] objectForKey:@"iphone"];

static BOOL debugMode = YES;

iCPButton buttonForString(NSString* string){
	char character = [string characterAtIndex:0];
	int result = 12;
	for(int i = 0; i < 12; i++)
	{
		if([presses characterAtIndex:i] == character || [releases characterAtIndex:i] == character)
		{
			result = i;
			break;
		}
	}
	return (iCPButton)result;
}
iCPButtonState buttonStateForString(NSString* string){
	char character = [string characterAtIndex:0];
	int result = 2;
	for(int i = 0; i < 12; i++)
	{
		if([presses characterAtIndex:i] == character) return PRESS;
		if([releases characterAtIndex:i] == character) return RELEASE;
	}
	return (iCPButtonState)result;
}

static void (*original_GSSendEvent)(GSEventRecord* record, mach_port_t port);
extern "C" void replaced_GSSendEvent(GSEventRecord* record, mach_port_t port)
{
	if(debugMode)
	{
		int gsEventType = record->type;
		if(gsEventType == 3001)
		{
			float locationX = (float)record->location.x;
			float locationY = (float)record->location.y;
			NSLog(@"touch at (%f, %f)", locationX, locationY);
		}
	}
	original_GSSendEvent(record, port);
}

__attribute__((constructor))
static void initialize()
{
	NSLog(@"MyExt: Loaded");
	MSHookFunction((void*)GSSendEvent, (void*)replaced_GSSendEvent, (void**)&original_GSSendEvent);
}

void sendButtonEvent(iCPButton button, iCPButtonState state) {
	CGPoint point;
	NSString* buttonName;
	switch(button)
	{
		case UP:
			buttonName = [NSString stringWithString:@"up"];
			break;
		case DOWN:
			buttonName = [NSString stringWithString:@"down"];
			break;
		case LEFT:
			buttonName = [NSString stringWithString:@"left"];
			break;
		case RIGHT:
			buttonName = [NSString stringWithString:@"right"];
			break;
		case X:
			buttonName = [NSString stringWithString:@"x"];
			break;
		case A:
			buttonName = [NSString stringWithString:@"a"];
			break;
		case B:
			buttonName = [NSString stringWithString:@"y"];
			break;
		case L:
			buttonName = [NSString stringWithString:@"l"];
			break;
		case R:
			buttonName = [NSString stringWithString:@"r"];
			break;
		case START:
			buttonName = [NSString stringWithString:@"start"];
			break;
		case SELECT:
			buttonName = [NSString stringWithString:@"select"];
			break;
		default:
			break;
	}
	if(buttonName != nil && [prefs objectForKey:buttonName] != nil)
	{
		point.x = [(NSNumber*)[(NSArray*)[prefs objectForKey:buttonName] objectAtIndex:0] floatValue];
		point.y = [(NSNumber*)[(NSArray*)[prefs objectForKey:buttonName] objectAtIndex:1] floatValue];
		if(state == PRESS)
		{
			UITouch *touch = [UITouch touchAtPoint: point];
			UIEvent* event = [UIEvent applicationEventWithTouch: touch];
			[event _addGestureRecognizersForView: touch.view toTouch: touch];
			for(NSString* touchName in [touches allKeys])
			{
				UITouch* eachTouch = [touches objectForKey:touchName];
				[event _addTouch:eachTouch forDelayedDelivery:NO];
				[event _addGestureRecognizersForView:eachTouch.view toTouch:eachTouch];
			}
			[touches setObject:touch forKey:buttonName];
			[event updateTimestamp];
			[[UIApplication sharedApplication] sendEvent: event];
		}
		else if(state == RELEASE)
		{
			UITouch* touch = [touches objectForKey:buttonName];
			UIEvent* event = [UIEvent applicationEventWithTouch: touch];
			[touches removeObjectForKey:buttonName];
			[event _addGestureRecognizersForView: touch.view toTouch: touch];
			for(NSString* touchName in [touches allKeys])
			{
				UITouch* eachTouch = [touches objectForKey:touchName];
				[event _addTouch:eachTouch forDelayedDelivery:NO];
				[event _addGestureRecognizersForView: eachTouch.view toTouch: eachTouch];
			}
			[event _addGestureRecognizersForView: touch.view toTouch: touch];    
			[event updateTimestamp];
			[touch setPhase:UITouchPhaseEnded];
			[[UIApplication sharedApplication] sendEvent: event];
		}
	}
}

%hook UIKeyboardInputManager
-(BOOL)acceptInputString:(id)string
{
	%log;
	
	NSString* lowercaseString = [string lowercaseString];
	
	iCPButton button = buttonForString(lowercaseString);
	iCPButtonState state = buttonStateForString(lowercaseString);
	
	sendButtonEvent(button, state);
    
	return %orig;
}
%end

%hook SBApplicationController
-(void)applicationStateChanged:(SBApplication*)changed state:(unsigned)state
{
	// 4 = open, active
	
	
	
	%orig;
	NSLog(@"%@ just changed to state %u", [changed displayIdentifier], state);
}
%end
	
