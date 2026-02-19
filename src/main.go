package main

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Cocoa
#include "proxy.h"
*/
import "C"

import (
	"fmt"
	"os"
	"unsafe"
)

var urlChan = make(chan urlEvent, 1)

type urlEvent struct {
	URL            string
	SenderBundleID string
	SenderName     string
	ChosenBrowser  string
	WasManual      bool
}

var browserBundleIDs = map[string]string{
	"chrome":  "com.google.Chrome",
	"firefox": "org.mozilla.firefox",
}

//export HandleURL
func HandleURL(url *C.char, senderBundleID *C.char, senderName *C.char, chosenBrowser *C.char, wasManualChoice C.int) {
	urlChan <- urlEvent{
		URL:            C.GoString(url),
		SenderBundleID: C.GoString(senderBundleID),
		SenderName:     C.GoString(senderName),
		ChosenBrowser:  C.GoString(chosenBrowser),
		WasManual:      wasManualChoice != 0,
	}
}

func main() {
	cfg := loadConfig()

	defaultBrowser := C.CString(cfg.DefaultBrowser)
	defer C.free(unsafe.Pointer(defaultBrowser))

	go C.RunApp(defaultBrowser)

	for {
		ev := <-urlChan
		go handleEvent(ev)
	}
}

func handleEvent(ev urlEvent) {
	cfg := loadConfig()

	browser := ev.ChosenBrowser
	if !ev.WasManual {
		browser = cfg.resolveBrowser(ev.SenderName, ev.SenderBundleID)
	}
	ev.ChosenBrowser = browser

	logEvent(ev)

	bundleID, ok := browserBundleIDs[browser]
	if !ok {
		bundleID = browserBundleIDs["chrome"]
	}

	cURL := C.CString(ev.URL)
	cBundleID := C.CString(bundleID)
	defer C.free(unsafe.Pointer(cURL))
	defer C.free(unsafe.Pointer(cBundleID))

	if C.OpenURLInBrowser(cURL, cBundleID) != 0 {
		fmt.Fprintf(os.Stderr, "browser-proxy: failed to open %s with %s\n", ev.URL, browser)
	}
}
