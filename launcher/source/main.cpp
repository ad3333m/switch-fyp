// ForYou - native launcher for the Switch homebrew TikTok-style "For You" web app.
//
// This does not render any UI itself. It brings up network access, then hands
// off to the console's built-in Web Applet pointed at a hosted web app, the
// same technique homebrew YouTube clients (e.g. LennyTube) use to get real
// video playback without writing a video codec from scratch.
//
// Configure the target URL at build time via the FORYOU_URL define (see
// Makefile), or fall back to a local page explaining how to set it.

#include <switch.h>
#include <cstdio>
#include <cstring>

#ifndef FORYOU_URL
#define FORYOU_URL "https://example.invalid/set-FORYOU_URL-at-build-time"
#endif

static void printCentered(PrintConsole* console, const char* msg) {
    consoleClear();
    printf("\n\n  ForYou launcher\n");
    printf("  ----------------\n\n");
    printf("  %s\n", msg);
    consoleUpdate(console);
}

// Blocks until the user presses + (or the applet is asked to quit), showing
// the given message. Used for error screens where there's nothing else to do.
static void waitForExit(PrintConsole* console, PadState* pad, const char* msg) {
    printCentered(console, msg);
    printf("  Press + to exit.\n");
    consoleUpdate(console);
    while (appletMainLoop()) {
        padUpdate(pad);
        u64 kDown = padGetButtonsDown(pad);
        if (kDown & HidNpadButton_Plus) break;
        consoleUpdate(console);
    }
}

int main(int argc, char* argv[]) {
    PrintConsole* console = consoleInit(NULL);

    PadState pad;
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    padInitializeDefault(&pad);

    printCentered(console, "Checking network connection...");

    Result rc = nifmInitialize(NifmServiceType_User);
    if (R_FAILED(rc)) {
        waitForExit(console, &pad, "Failed to initialize network service (nifm).");
        consoleExit(NULL);
        return 1;
    }

    NifmInternetConnectionType connType;
    u32 wifiStrength;
    NifmInternetConnectionStatus connStatus;
    rc = nifmGetInternetConnectionStatus(&connType, &wifiStrength, &connStatus);

    bool connected = R_SUCCEEDED(rc) && connStatus == NifmInternetConnectionStatus_Connected;

    if (!connected) {
        waitForExit(console, &pad, "No internet connection.\n  Connect to Wi-Fi in System Settings, then relaunch.");
        nifmExit();
        consoleExit(NULL);
        return 1;
    }

    printCentered(console, "Opening For You...");

    // Launch the system Web Applet pointed at the hosted TikTok-style web app.
    // This gives us a real browser engine: real <video> playback, real CSS/JS
    // animation, and a live network fetch of the feed on every launch -
    // nothing is bundled or pre-imported onto the SD card.
    WebCommonConfig webConfig;
    rc = webPageCreate(&webConfig, FORYOU_URL);
    if (R_SUCCEEDED(rc)) {
        webConfigSetWhitelist(&webConfig, "^http{s,}://.*");
        webConfigSetFooter(&webConfig, false);
        webConfigSetPointer(&webConfig, true);
        webConfigSetLeftStickMode(&webConfig, WebLeftStickMode_Cursor);

        WebCommonReply webReply;
        rc = webConfigShow(&webConfig, &webReply);
    }

    if (R_FAILED(rc)) {
        waitForExit(console, &pad, "Failed to open the Web Applet.");
    }

    nifmExit();
    consoleExit(NULL);
    return 0;
}
