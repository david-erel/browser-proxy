#include "proxy.h"
#include "_cgo_export.h"
#include <sys/types.h>

static NSString *gDefaultBrowser = nil;

@implementation ProxyAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    NSAppleEventManager *aem = [NSAppleEventManager sharedAppleEventManager];
    [aem setEventHandler:self
             andSelector:@selector(handleGetURLEvent:withReplyEvent:)
           forEventClass:kInternetEventClass
              andEventID:kAEGetURL];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event
           withReplyEvent:(NSAppleEventDescriptor *)replyEvent {

    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if (!urlString) return;

    // Extract sender application info
    NSString *senderBundleId = @"";
    NSString *senderName = @"";

    NSAppleEventDescriptor *addrDesc = [event attributeDescriptorForKeyword:keyAddressAttr];
    if (addrDesc) {
        NSAppleEventDescriptor *pidDesc = [addrDesc coerceToDescriptorType:typeKernelProcessID];
        if (pidDesc) {
            pid_t pid = 0;
            NSData *pidData = [pidDesc data];
            if (pidData && [pidData length] >= sizeof(pid_t)) {
                pid = *(const pid_t *)[pidData bytes];
            }
            if (pid > 0) {
                NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
                if (app) {
                    if (app.bundleIdentifier) senderBundleId = app.bundleIdentifier;
                    if (app.localizedName) senderName = app.localizedName;
                }
            }
        }
    }

    // Check if Option key is held
    NSEventModifierFlags flags = [NSEvent modifierFlags];
    BOOL optionHeld = (flags & NSEventModifierFlagOption) != 0;

    NSString *chosenBrowser = gDefaultBrowser ?: @"chrome";
    int wasManual = 0;

    if (optionHeld) {
        [NSApp activateIgnoringOtherApps:YES];

        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Choose Browser"];

        NSString *infoText = urlString;
        if ([infoText length] > 120) {
            infoText = [[infoText substringToIndex:117] stringByAppendingString:@"..."];
        }
        [alert setInformativeText:infoText];
        [alert addButtonWithTitle:@"Chrome"];
        [alert addButtonWithTitle:@"Firefox"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setAlertStyle:NSAlertStyleInformational];

        NSString *iconPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"AppIcon.icns"];
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
        if (icon) [alert setIcon:icon];

        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            chosenBrowser = @"chrome";
        } else if (response == NSAlertSecondButtonReturn) {
            chosenBrowser = @"firefox";
        } else {
            return;
        }
        wasManual = 1;
    }

    HandleURL(
        (char *)[urlString UTF8String],
        (char *)[senderBundleId UTF8String],
        (char *)[senderName UTF8String],
        (char *)[chosenBrowser UTF8String],
        wasManual
    );
}

@end

int OpenURLInBrowser(const char* url, const char* bundleID) {
    NSString *urlStr = [NSString stringWithUTF8String:url];
    NSString *bid = [NSString stringWithUTF8String:bundleID];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block int result = 0;

    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSURL *nsURL = [NSURL URLWithString:urlStr];
            if (!nsURL) {
                NSLog(@"browser-proxy: invalid URL: %@", urlStr);
                result = -1;
                dispatch_semaphore_signal(sem);
                return;
            }

            NSURL *appURL = [[NSWorkspace sharedWorkspace]
                URLForApplicationWithBundleIdentifier:bid];
            if (!appURL) {
                NSLog(@"browser-proxy: app not found for bundle ID: %@", bid);
                result = -1;
                dispatch_semaphore_signal(sem);
                return;
            }

            NSArray<NSRunningApplication *> *running =
                [NSRunningApplication runningApplicationsWithBundleIdentifier:bid];

            void (^openURL)(void) = ^{
                NSWorkspaceOpenConfiguration *urlConfig = [NSWorkspaceOpenConfiguration configuration];
                [[NSWorkspace sharedWorkspace] openURLs:@[nsURL]
                                   withApplicationAtURL:appURL
                                          configuration:urlConfig
                                      completionHandler:^(NSRunningApplication *app, NSError *error) {
                    if (error) {
                        NSLog(@"browser-proxy: open failed: %@", error);
                        result = -1;
                    }
                    dispatch_semaphore_signal(sem);
                }];
            };

            if ([running count] == 0) {
                NSWorkspaceOpenConfiguration *launchConfig = [NSWorkspaceOpenConfiguration configuration];
                [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                      configuration:launchConfig
                                                  completionHandler:^(NSRunningApplication *app, NSError *error) {
                    if (error) {
                        NSLog(@"browser-proxy: launch failed: %@", error);
                        result = -1;
                        dispatch_semaphore_signal(sem);
                        return;
                    }
                    dispatch_after(
                        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                        dispatch_get_main_queue(),
                        openURL
                    );
                }];
            } else {
                openURL();
            }
        }
    });

    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    return result;
}

void RunApp(const char* defaultBrowser) {
    @autoreleasepool {
        if (defaultBrowser) {
            gDefaultBrowser = [NSString stringWithUTF8String:defaultBrowser];
        }
        [NSApplication sharedApplication];
        NSString *iconPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"AppIcon.icns"];
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
        if (icon) [NSApp setApplicationIconImage:icon];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        ProxyAppDelegate *delegate = [[ProxyAppDelegate alloc] init];
        [NSApp setDelegate:delegate];
        [NSApp run];
    }
}
