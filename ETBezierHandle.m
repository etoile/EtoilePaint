/*
	Copyright (C) 2009 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date: August 2009
    License:  Modified BSD (see COPYING)
 */
#import <CoreObject/COObject.h>
#import <EtoileFoundation/Macros.h>
#import <EtoileUI/ETGeometry.h>
#import <EtoileUI/ETShape.h>
#import <EtoileUI/ETCompatibility.h>
#import "ETBezierHandle.h"

@implementation ETBezierHandle

- (id) initWithActionHandler: (ETActionHandler *)anHandler
           manipulatedObject: (id)aTarget
                    partcode: (ETBezierPathPartcode)partcode
		  objectGraphContext: (COObjectGraphContext *)aContext
{
	self = [super initWithActionHandler: anHandler
	                  manipulatedObject: aTarget
					 objectGraphContext: aContext];
	if (nil == self)
	{
		return nil;
	}
	_partcode = partcode;
	
	if ([[self manipulatedPath] isControlPoint: [self partcode]])
	{
		[self setStyle: [ETBezierControlPointStyle sharedInstance]];
	}
	else
	{
		[self setStyle: [ETBezierPointStyle sharedInstance]];
	}
	NSLog(@"Bezier handle %@ created, manip path %@", self, [self manipulatedPath]);
	
	return self;
}

- (ETBezierPathPartcode) partcode
{
	return _partcode;
}

- (NSBezierPath *) manipulatedPath
{
	return (NSBezierPath *)[(ETShape *)[[self manipulatedObject] style] path];
}

@end

@implementation ETBezierHandleGroup

- (id) initWithManipulatedObject: (id)aTarget
			  objectGraphContext: (COObjectGraphContext *)aContext
{
	return [self initWithActionHandler: nil manipulatedObject: aTarget objectGraphContext: aContext];
}

- (id) initWithActionHandler: (ETActionHandler *)anHandler
           manipulatedObject: (id)aTarget
		  objectGraphContext: (COObjectGraphContext *)aContext
{
	NSMutableArray *handles = [NSMutableArray array];
	
	// FIXME: assumption
	ETShape *shape = (ETShape *)[aTarget style];
	NSBezierPath *path = [shape path];
	
	unsigned int count = [path elementCount];
	NSPoint	points[3];
	NSBezierPathElement type;
	for (unsigned int  i = 0; i < count; i++ )
	{
		type = [path elementAtIndex:i associatedPoints:points];
		switch (type)
		{
			// FIXME: ugly
			case NSCurveToBezierPathElement:
				[handles addObject: AUTORELEASE([[ETBezierHandle alloc] initWithActionHandler: [ETBezierPointActionHandler sharedInstance]
				                                                            manipulatedObject: aTarget
																			         partcode: [path partcodeForControlPoint: 0 ofElement: i]
																		   objectGraphContext: (COObjectGraphContext *)aContext])];
				[handles addObject: AUTORELEASE([[ETBezierHandle alloc] initWithActionHandler: [ETBezierPointActionHandler sharedInstance]
				                                                            manipulatedObject: aTarget
																			         partcode: [path partcodeForControlPoint: 1 ofElement: i]
																		   objectGraphContext: (COObjectGraphContext *)aContext])];
				[handles addObject: AUTORELEASE([[ETBezierHandle alloc] initWithActionHandler: [ETBezierPointActionHandler sharedInstance]
				                                                            manipulatedObject: aTarget
																			         partcode: [path partcodeForControlPoint: 2 ofElement: i]
																		   objectGraphContext: (COObjectGraphContext *)aContext])];
				break;	
			case NSMoveToBezierPathElement:
			case NSLineToBezierPathElement:
				[handles addObject: AUTORELEASE([[ETBezierHandle alloc] initWithActionHandler: [ETBezierPointActionHandler sharedInstance]
				                                                            manipulatedObject: aTarget
																			         partcode: [path partcodeForElement: i]
																		   objectGraphContext: (COObjectGraphContext *)aContext])];
				break;
			case NSClosePathBezierPathElement:
				break;
			default:
				break;
		}
	}
	
	self = [super initWithView: nil coverStyle: nil actionHandler: anHandler objectGraphContext: aContext];
	if (self == nil)
		return nil;
	
	[self setFlipped: YES];
	[self setStyle: nil]; /* Suppress the default ETLayoutItem style */
	//[self setActionHandler: anHandler];
	[self setManipulatedObject: aTarget];
	[self addItems: handles];

	// FIXME: assumption
	[self updateHandleLocations];
	
	return self;
}

- (NSBezierPath *) manipulatedPath
{
	NSLog(@"manip obj %@, style %@", [self manipulatedObject] , [[self manipulatedObject] style]);
	ETShape *shape = (ETShape *)[[self manipulatedObject] style];
	NSBezierPath *path = [shape path];
	NSAssert(path != nil, @"Path is nil");
	return path;
}

- (void) updateHandleLocations
{
	FOREACH([self items], handle, ETBezierHandle *)
	{
		NSLog(@"set handle %@ pc: %d to %@", handle, [handle partcode], NSStringFromPoint([[self manipulatedPath] pointForPartcode: [handle partcode]]));
		[handle setPosition: [[self manipulatedPath] pointForPartcode: [handle partcode]]];
	}
}


- (id) manipulatedObject
{
	return [self valueForVariableStorageKey: kETManipulatedObjectProperty];
}

- (void) setManipulatedObject: (id)anObject
{
	[self setValue: anObject forVariableStorageKey: kETManipulatedObjectProperty];
	/* Better to avoid -setFrame: which would update the represented object frame. */
	// FIXME: Ugly duplication with -setFrame:... 
	//[self setFrame: [anObject frame]];
	[self setRepresentedObject: anObject];
	[self updateHandleLocations];
}

- (NSPoint) anchorPoint
{
	return [(ETLayoutItem *)[self valueForVariableStorageKey: kETManipulatedObjectProperty] anchorPoint];
}

- (void) setAnchorPoint: (NSPoint)anchor
{
	return [(ETLayoutItem *)[self valueForVariableStorageKey: kETManipulatedObjectProperty] setAnchorPoint: anchor];
}

- (NSPoint) position
{
	return [(ETLayoutItem *)[self valueForVariableStorageKey: kETManipulatedObjectProperty] position];
}

- (void) setPosition: (NSPoint)aPosition
{
	[(ETLayoutItem *)[self valueForVariableStorageKey: kETManipulatedObjectProperty] setPosition: aPosition];
	[self updateHandleLocations];
}

/** Returns the content bounds associated with the receiver. */
- (NSRect) contentBounds
{
	NSRect manipulatedFrame = [[self valueForVariableStorageKey: kETManipulatedObjectProperty] frame];
	return ETMakeRect(NSZeroPoint, manipulatedFrame.size);
}

- (void) setContentBounds: (NSRect)rect
{
	NSRect manipulatedFrame = ETMakeRect([[self valueForVariableStorageKey: kETManipulatedObjectProperty] origin], rect.size);
	[[self valueForVariableStorageKey: kETManipulatedObjectProperty] setFrame: manipulatedFrame];
	[self updateHandleLocations];
}

- (NSRect) frame
{
	return [[self valueForVariableStorageKey: kETManipulatedObjectProperty] frame];
}

// NOTE: We need to figure out what we really needs. For example,
// -setBoundingBox: could be called when a handle group is inserted, or the 
// layout and/or the style could have a hook -boundingBoxForItem:. We 
// probably want to cache the bounding box value in an ivar too.
- (void) setFrame: (NSRect)frame
{
	[[self valueForVariableStorageKey: kETManipulatedObjectProperty] setFrame: frame];
	[self updateHandleLocations];
}

- (void) setBoundingBox: (NSRect)extent
{
	[super setBoundingBox: extent];
	[[self valueForVariableStorageKey: kETManipulatedObjectProperty] setBoundingBox: extent];
}

/** Marks both the receiver and its manipulated object as invalidated area 
or not. */
- (void) setNeedsDisplay: (BOOL)flag
{
	[super setNeedsDisplay: flag];
	[[self manipulatedObject] setNeedsDisplay: flag];
}

/** Returns YES. */
- (BOOL) acceptsActionsForItemsOutsideOfFrame
{
	return YES;
}


@end

/* Action and Style Aspects */

/**
 * Unlike EUI's ETHandle implementation for resizing handles where the
 * manipulated object of the handles is the handle group, in this
 * case, the manipulated object of the handles is the actual layout
 * item being manipulated.
 *
 * FIXME: I should probably switch to that model..
 */
@implementation ETBezierPointActionHandler

- (void) handleTranslateItem: (ETHandle *)handle byDelta: (NSSize)delta
{
	NSBezierPath *path = [(ETBezierHandle *)handle manipulatedPath];
	ETBezierPathPartcode partcode = [(ETBezierHandle *)handle partcode];
	NSPoint point = ETSumPointAndSize([handle position], delta);
	
	[path moveControlPointPartcode: partcode toPoint: point colinear:NO coradial: NO constrainAngle: NO];
	[handle setPosition: point];

	ETLayoutItem *item = [handle manipulatedObject];
	[item setNeedsDisplay: YES]; /* Invalidate existing rect */

	// Enlarge the frame of the manipulated item, if needed.
	NSRect manipulatedFrame = [item frame];
	// FIXME: assumes item is flipped
	
	// FIXME: this is very wrong..
	manipulatedFrame = NSUnionRect(manipulatedFrame, ETMakeRect(ETSumPoint(point, manipulatedFrame.origin), NSMakeSize(1.0, 1.0)));
	NSLog(@"point: %@, summed %@,  old frame: %@ manip %@", NSStringFromPoint(point), NSStringFromRect(ETMakeRect(ETSumPoint(point, manipulatedFrame.origin), NSZeroSize)), NSStringFromRect([item frame]), NSStringFromRect(manipulatedFrame));
	[item setBoundingBox: NSMakeRect(0, 0, manipulatedFrame.size.width, manipulatedFrame.size.height)];

	//[item setNeedsDisplay: YES];/* Invalidate new resized rect */
}
@end

@implementation ETBezierControlPointActionHandler
- (void) handleTranslateItem: (ETHandle *)handle byDelta: (NSSize)delta
{
}
@end



@implementation ETBezierPointStyle

static ETBezierPointStyle *sharedBezierPointStyle = nil;

+ (id) sharedInstance
{
	if (sharedBezierPointStyle == nil)
		sharedBezierPointStyle = [[ETBezierPointStyle alloc] init];
		
	return sharedBezierPointStyle;
}

/** Draws the interior of the handle. */
- (void) drawHandleInRect: (NSRect)rect
{
	[[[NSColor orangeColor] colorWithAlphaComponent: 0.80] setFill];
	[[NSBezierPath bezierPathWithOvalInRect: rect] fill];
}

@end

@implementation ETBezierControlPointStyle

static ETBezierControlPointStyle *sharedBezierControlPointStyle = nil;

+ (id) sharedInstance
{
	if (sharedBezierControlPointStyle == nil)
		sharedBezierControlPointStyle = [[ETBezierControlPointStyle alloc] init];
		
	return sharedBezierControlPointStyle;
}

/** Draws the interior of the handle. */
- (void) drawHandleInRect: (NSRect)rect
{
	[[[NSColor cyanColor] colorWithAlphaComponent: 0.80] setFill];
	NSRectFill(rect);
}

@end
