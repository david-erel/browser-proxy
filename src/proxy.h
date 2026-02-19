#ifndef PROXY_H
#define PROXY_H

#import <Cocoa/Cocoa.h>

@interface ProxyAppDelegate : NSObject <NSApplicationDelegate>
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event
           withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
@end

void RunApp(const char* defaultBrowser);
int OpenURLInBrowser(const char* url, const char* bundleID);

#endif
