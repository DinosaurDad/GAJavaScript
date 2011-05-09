/*
 Copyright (c) 2010 Andrew Goodale. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are
 permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of
 conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list
 of conditions and the following disclaimer in the documentation and/or other materials
 provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY ANDREW GOODALE "AS IS" AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 The views and conclusions contained in the software and documentation are those of the
 authors and should not be interpreted as representing official policies, either expressed
 or implied, of Andrew Goodale.
*/

#import "TScriptObject.h"
#import "GAScriptObject.h"
#import "NSObject+GAJavaScript.h"
#import "UIWebView+GAJavaScript.h"

@implementation TScriptObject

- (BOOL)shouldRunOnMainThread 
{
	// By default NO, but if you have a UI test or test dependent on running on the main thread return YES
	return YES;
}

- (void)setUp
{
	UIApplication* app = [UIApplication sharedApplication];
	UIWindow* mainWindow = app.keyWindow;
	
	m_webView = (UIWebView *) [mainWindow viewWithTag:9999];	
}

- (BOOL)compareValues:(id)gotValue testValue:(id)testValue
{	
	// I don't know why regular isEqual: and compare: don't work for floating point numbers,
	// so I need to compare the decimal values specifically. Weird.
	if ([testValue isKindOfClass:[NSNumber class]])
	{
		NSDecimal dec1 = [testValue decimalValue];
		NSDecimal dec2 = [gotValue decimalValue];
		
		return (NSDecimalCompare(&dec1, &dec2) == NSOrderedSame);
	}
	else if ([testValue isKindOfClass:[NSDate class]])
	{
		// There will be a sub-second difference between the values due to rounding of NSTimeInterval
		// when it's passed into JavaScript. So we validate that the times are within 1 second.
		return ([testValue timeIntervalSinceDate:gotValue] < 1.0);		
	}
	else if (![gotValue isEqual:testValue])
	{
		GHTestLog(@"get/setValue failed for %@", testValue);
		return NO;
	}	
	
	return YES;
}

- (void)testKeyValueCoding
{
	NSArray* kTestValues = [NSArray arrayWithObjects:
							@"abcd",							// String
							@"string 'with' quotes",			// String that needs escaping
							[NSNumber numberWithInt:400000],	// Number (Integer)
							[NSNumber numberWithFloat:0.55555],	// Number (Float)
							[NSNull null],						// Null
							[NSNumber numberWithBool:YES],		// Boolean
							[NSDate date],						// Date
							nil];
	
	GAScriptObject* jsObject = [m_webView newScriptObject];

	for (id testValue in kTestValues)
	{
		[jsObject setValue:testValue forKey:@"js_test"];
		id gotValue = [jsObject valueForKey:@"js_test"];
		
		GHAssertTrue([self compareValues:gotValue testValue:testValue], nil);
	}
	
	// Test with a character that cannot be in an identifier
	//
	id testValue = @"rgb(1, 2, 3)";
	[jsObject setValue:testValue forKey:@"background-color"];
	id gotValue = [jsObject valueForKey:@"background-color"];
	
	GHAssertTrue([self compareValues:gotValue testValue:testValue], nil);	
	
	[jsObject release];
}

- (void)testKeyValueCodingWithArrays
{
	NSArray* kTestValues = [NSArray arrayWithObjects:
							@"abcd",							// String
							@"string 'with' quotes",			// String that needs escaping
							[NSNumber numberWithInt:400000],	// Number (Integer)
							[NSNumber numberWithFloat:0.55555],	// Number (Float)
							[NSNull null],						// Null
							[NSNumber numberWithBool:YES],		// Boolean
							[NSDate date],						// Date
							nil];
	
	GAScriptObject* jsObject = [m_webView newScriptObject];
	
	[jsObject setValue:kTestValues forKey:@"js_test"];
	NSArray* gotValue = [jsObject valueForKey:@"js_test"];
		
	GHAssertTrue([gotValue isKindOfClass:[NSArray class]], nil);

	for (NSInteger i = 0; i < [gotValue count]; ++i)
	{
		GHAssertTrue([self compareValues:[gotValue objectAtIndex:i] testValue:[kTestValues objectAtIndex:i]], nil);
	}
	
	[jsObject release];
}	

- (void)testKeyValueCodingWithDictionary
{
	NSDictionary* kTestDict = [NSDictionary dictionaryWithObjectsAndKeys:
							   @"abcd", @"string",							
							   @"string 'with' quotes", @"string_with_quotes",
							   [NSNumber numberWithInt:400000],	    @"integer",
							   [NSNumber numberWithFloat:0.55555],	@"float",
							   [NSNull null],						@"nullprop",
							   [NSNumber numberWithBool:YES],		@"boolprop",
							   [NSDate date],						@"dateprop",
							   nil];
	
	GAScriptObject* jsObject = [m_webView newScriptObject];
	
	[jsObject setValue:kTestDict forKey:@"js_test"];
	GAScriptObject* gotValue = [jsObject valueForKey:@"js_test"];
	
	GHAssertTrue([gotValue isKindOfClass:[GAScriptObject class]], nil);
	
	for (NSString* key in kTestDict)
	{
		GHAssertTrue([self compareValues:[gotValue valueForKey:key] testValue:[kTestDict objectForKey:key]], nil);
	}
	
	[jsObject release];
}	

- (void)testAllKeys
{
	GAScriptObject* jsObject = [[GAScriptObject alloc] initForReference:@"location" view:m_webView];
	NSArray* allKeys = [jsObject allKeys];
		
	GHAssertNotNil(allKeys, nil);
	GHAssertTrue([allKeys count] != 0, nil);
	GHAssertTrue([allKeys containsObject:@"hostname"], nil);
	
	[jsObject release];
}

- (void)testFastEnumeration
{
	GAScriptObject* jsObject = [[GAScriptObject alloc] initForReference:@"location" view:m_webView];
	BOOL foundHostName = NO;
	
	for (id key in jsObject)
	{
		if ([key isEqual:@"hostname"])
			foundHostName = YES;
	}

	GHAssertTrue(foundHostName, nil);
	[jsObject release];
}

- (void)testCallFunction
{
	GAScriptObject* jsObject = [[GAScriptObject alloc] initForReference:@"document" view:m_webView];
	id retVal = [jsObject callFunction:@"createElement" withObject:@"strong"];

	GHAssertTrue([retVal isKindOfClass:[GAScriptObject class]], nil);
	
	[jsObject release];
}

- (void)testJavaScriptTrue
{
	GAScriptObject* jsObject = [m_webView newScriptObject];
	
	[jsObject setValue:[NSNull null] forKey:@"prop-null"];
	[jsObject setValue:[NSNumber numberWithFloat:0.0] forKey:@"prop-num"];
	[jsObject setValue:[NSNumber numberWithBool:YES] forKey:@"prop-bool"];
	[jsObject setValue:@"" forKey:@"prop-str"];
	
	GHAssertFalse([[jsObject valueForKey:@"prop-null"] isJavaScriptTrue], @"NSNull failed");
	GHAssertFalse([[jsObject valueForKey:@"prop-num"] isJavaScriptTrue], @"NSNumber failed");
	GHAssertTrue([[jsObject valueForKey:@"prop-bool"] isJavaScriptTrue], @"BOOL failed");
	GHAssertFalse([[jsObject valueForKey:@"prop-str"] isJavaScriptTrue], @"NSString failed");
	
	[jsObject release];
}

@end