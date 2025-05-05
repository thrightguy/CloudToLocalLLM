#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <map>
#include <string>

#include "flutter_window.h"
#include "utils.h"

// Custom message for system tray interactions
#define WM_SYSTEM_TRAY (WM_USER + 1)
#define ID_TRAY_APP_ICON 1001
#define ID_TRAY_EXIT 1002
#define ID_TRAY_SHOW 1003
#define ID_TRAY_LLM_STATUS 1004
#define ID_TRAY_TUNNEL_CONNECT 1005
#define ID_TRAY_TUNNEL_DISCONNECT 1006
#define ID_TRAY_TUNNEL_STATUS 1007
#define ID_TRAY_TUNNEL_COPY_URL 1008

// Global variables
NOTIFYICONDATA g_notifyIconData;
HMENU g_menu;
bool g_isWindowVisible = true;
bool g_isLlmRunning = false;
bool g_isTunnelConnected = false;
std::string g_tunnelUrl = "";

// Flutter engine for method calls
flutter::FlutterEngine* g_engine = nullptr;

// Forward declarations
LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);
void SetupSystemTray(HWND hwnd);
void UpdateSystemTrayIcon(bool isLlmRunning, bool isTunnelConnected);
void CleanupSystemTray();
void ShowContextMenu(HWND hwnd, POINT pt);
bool StartLlmService();
bool CheckLlmStatus();
void ConnectTunnel();
void DisconnectTunnel();
bool CheckTunnelStatus();
void CopyTunnelUrl();
void SetupMethodChannel();

// Method channel for communication with Dart code
std::unique_ptr<flutter::MethodChannel<>> g_channel;

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"CloudToLocalLLM", origin, size)) {
    return EXIT_FAILURE;
  }
  
  // Always show window on startup
  window.Show();
  g_isWindowVisible = true;

  // Don't auto-quit when the window is closed
  window.SetQuitOnClose(false);

  // Store engine pointer for method channel
  g_engine = window.GetEngine();

  // Set up the method channel for communication with Dart
  if (g_engine) {
    SetupMethodChannel();
  }

  // Set up custom window procedure to handle system tray operations
  HWND hwnd = window.GetHandle();
  SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&window));
  SetWindowLongPtr(hwnd, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(WindowProc));
  
  // Setup system tray
  SetupSystemTray(hwnd);
  
  // Start LLM service
  g_isLlmRunning = StartLlmService();
  
  // Check tunnel status
  g_isTunnelConnected = CheckTunnelStatus();
  
  // Update system tray
  UpdateSystemTrayIcon(g_isLlmRunning, g_isTunnelConnected);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // Cleanup
  CleanupSystemTray();
  ::CoUninitialize();
  return EXIT_SUCCESS;
}

// Set up the method channel for communication with Dart
void SetupMethodChannel() {
  g_channel = std::make_unique<flutter::MethodChannel<>>(
      g_engine->messenger(),
      "com.cloudtolocalllm/windows",
      &flutter::StandardMethodCodec::GetInstance());

  g_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<>& call, 
         std::unique_ptr<flutter::MethodResult<>> result) {
        // Handle method calls from Dart
        if (call.method_name() == "updateTunnelStatus") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto isConnectedIter = arguments->find(flutter::EncodableValue("isConnected"));
            auto urlIter = arguments->find(flutter::EncodableValue("url"));
            
            if (isConnectedIter != arguments->end() && 
                urlIter != arguments->end()) {
              g_isTunnelConnected = std::get<bool>(isConnectedIter->second);
              g_tunnelUrl = std::get<std::string>(urlIter->second);
              
              // Update system tray
              UpdateSystemTrayIcon(g_isLlmRunning, g_isTunnelConnected);
              
              result->Success();
              return;
            }
          }
        } else if (call.method_name() == "updateLlmStatus") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto isRunningIter = arguments->find(flutter::EncodableValue("isRunning"));
            
            if (isRunningIter != arguments->end()) {
              g_isLlmRunning = std::get<bool>(isRunningIter->second);
              
              // Update system tray
              UpdateSystemTrayIcon(g_isLlmRunning, g_isTunnelConnected);
              
              result->Success();
              return;
            }
          }
        }
        
        result->NotImplemented();
      });
}

// Custom window procedure to handle system tray messages
LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
  switch (message) {
    case WM_SYSTEM_TRAY:
      if (lParam == WM_LBUTTONUP || lParam == WM_RBUTTONUP) {
        POINT pt;
        GetCursorPos(&pt);
        ShowContextMenu(hwnd, pt);
        return 0;
      }
      break;

    case WM_COMMAND:
      switch (LOWORD(wParam)) {
        case ID_TRAY_EXIT:
          PostQuitMessage(0);
          return 0;
        case ID_TRAY_SHOW:
          g_isWindowVisible = !g_isWindowVisible;
          ShowWindow(hwnd, g_isWindowVisible ? SW_SHOW : SW_HIDE);
          if (g_isWindowVisible) {
            SetForegroundWindow(hwnd);
            SetFocus(hwnd);
          }
          return 0;
        case ID_TRAY_LLM_STATUS:
          g_isLlmRunning = CheckLlmStatus();
          UpdateSystemTrayIcon(g_isLlmRunning, g_isTunnelConnected);
          return 0;
        case ID_TRAY_TUNNEL_CONNECT:
          ConnectTunnel();
          return 0;
        case ID_TRAY_TUNNEL_DISCONNECT:
          DisconnectTunnel();
          return 0;
        case ID_TRAY_TUNNEL_STATUS:
          g_isTunnelConnected = CheckTunnelStatus();
          UpdateSystemTrayIcon(g_isLlmRunning, g_isTunnelConnected);
          return 0;
        case ID_TRAY_TUNNEL_COPY_URL:
          CopyTunnelUrl();
          return 0;
      }
      break;

    case WM_CLOSE:
      // Hide the window instead of closing when user clicks X
      ShowWindow(hwnd, SW_HIDE);
      g_isWindowVisible = false;
      return 0;

    case WM_SIZE:
      if (wParam == SIZE_MINIMIZED) {
        // Hide window when minimized
        ShowWindow(hwnd, SW_HIDE);
        g_isWindowVisible = false;
        return 0;
      }
      break;
  }

  // Pass all other messages to Flutter's window procedure
  FlutterWindow* flutterWindow = reinterpret_cast<FlutterWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (flutterWindow) {
    return flutterWindow->MessageHandler(hwnd, message, wParam, lParam);
  }
  
  return DefWindowProc(hwnd, message, wParam, lParam);
}

// Set up the system tray icon
void SetupSystemTray(HWND hwnd) {
  g_menu = CreatePopupMenu();
  AppendMenu(g_menu, MF_STRING, ID_TRAY_SHOW, L"Show/Hide Window");
  
  // LLM management
  AppendMenu(g_menu, MF_STRING, ID_TRAY_LLM_STATUS, L"Check LLM Status");
  
  // Tunnel management
  AppendMenu(g_menu, MF_SEPARATOR, 0, L"");
  AppendMenu(g_menu, MF_STRING, ID_TRAY_TUNNEL_CONNECT, L"Connect Tunnel");
  AppendMenu(g_menu, MF_STRING, ID_TRAY_TUNNEL_DISCONNECT, L"Disconnect Tunnel");
  AppendMenu(g_menu, MF_STRING, ID_TRAY_TUNNEL_STATUS, L"Check Tunnel Status");
  AppendMenu(g_menu, MF_STRING, ID_TRAY_TUNNEL_COPY_URL, L"Copy Tunnel URL");
  
  // Exit option
  AppendMenu(g_menu, MF_SEPARATOR, 0, L"");
  AppendMenu(g_menu, MF_STRING, ID_TRAY_EXIT, L"Exit");

  ZeroMemory(&g_notifyIconData, sizeof(NOTIFYICONDATA));
  g_notifyIconData.cbSize = sizeof(NOTIFYICONDATA);
  g_notifyIconData.hWnd = hwnd;
  g_notifyIconData.uID = ID_TRAY_APP_ICON;
  g_notifyIconData.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  g_notifyIconData.uCallbackMessage = WM_SYSTEM_TRAY;
  g_notifyIconData.hIcon = LoadIcon(GetModuleHandle(NULL), MAKEINTRESOURCE(101)); // Default app icon
  wcscpy_s(g_notifyIconData.szTip, L"CloudToLocalLLM");
  
  Shell_NotifyIcon(NIM_ADD, &g_notifyIconData);
}

// Update the system tray icon based on LLM and tunnel status
void UpdateSystemTrayIcon(bool isLlmRunning, bool isTunnelConnected) {
  // Update the icon and tooltip based on status
  wchar_t tooltip[128];
  
  if (isLlmRunning && isTunnelConnected) {
    swprintf_s(tooltip, L"CloudToLocalLLM - LLM Running - Tunnel Connected");
  } else if (isLlmRunning) {
    swprintf_s(tooltip, L"CloudToLocalLLM - LLM Running - Tunnel Disconnected");
  } else if (isTunnelConnected) {
    swprintf_s(tooltip, L"CloudToLocalLLM - LLM Stopped - Tunnel Connected");
  } else {
    swprintf_s(tooltip, L"CloudToLocalLLM - LLM Stopped - Tunnel Disconnected");
  }
  
  wcscpy_s(g_notifyIconData.szTip, tooltip);
  
  // Different icon based on combined status would be ideal
  // For now using the same icon
  g_notifyIconData.hIcon = LoadIcon(GetModuleHandle(NULL), MAKEINTRESOURCE(101));
  
  Shell_NotifyIcon(NIM_MODIFY, &g_notifyIconData);
}

// Clean up the system tray icon
void CleanupSystemTray() {
  Shell_NotifyIcon(NIM_DELETE, &g_notifyIconData);
  if (g_menu) {
    DestroyMenu(g_menu);
  }
}

// Show the system tray context menu
void ShowContextMenu(HWND hwnd, POINT pt) {
  // Update menu item text based on window visibility
  ModifyMenu(g_menu, ID_TRAY_SHOW, MF_BYCOMMAND | MF_STRING, ID_TRAY_SHOW, 
             g_isWindowVisible ? L"Hide Window" : L"Show Window");
  
  // Update LLM status menu item based on running state
  ModifyMenu(g_menu, ID_TRAY_LLM_STATUS, MF_BYCOMMAND | MF_STRING, ID_TRAY_LLM_STATUS, 
             g_isLlmRunning ? L"LLM: Running" : L"LLM: Stopped");
  
  // Update tunnel menu items based on connected state
  if (g_isTunnelConnected) {
    ModifyMenu(g_menu, ID_TRAY_TUNNEL_CONNECT, MF_BYCOMMAND | MF_STRING | MF_GRAYED, 
               ID_TRAY_TUNNEL_CONNECT, L"Connect Tunnel");
    ModifyMenu(g_menu, ID_TRAY_TUNNEL_DISCONNECT, MF_BYCOMMAND | MF_STRING, 
               ID_TRAY_TUNNEL_DISCONNECT, L"Disconnect Tunnel");
    ModifyMenu(g_menu, ID_TRAY_TUNNEL_STATUS, MF_BYCOMMAND | MF_STRING, 
               ID_TRAY_TUNNEL_STATUS, L"Tunnel: Connected");
    
    // Only enable Copy URL if we have a URL
    if (!g_tunnelUrl.empty()) {
      ModifyMenu(g_menu, ID_TRAY_TUNNEL_COPY_URL, MF_BYCOMMAND | MF_STRING, 
                 ID_TRAY_TUNNEL_COPY_URL, L"Copy Tunnel URL");
    } else {
      ModifyMenu(g_menu, ID_TRAY_TUNNEL_COPY_URL, MF_BYCOMMAND | MF_STRING | MF_GRAYED, 
                 ID_TRAY_TUNNEL_COPY_URL, L"Copy Tunnel URL");
    }
  } else {
    ModifyMenu(g_menu, ID_TRAY_TUNNEL_CONNECT, MF_BYCOMMAND | MF_STRING, 
               ID_TRAY_TUNNEL_CONNECT, L"Connect Tunnel");
    ModifyMenu(g_menu, ID_TRAY_TUNNEL_DISCONNECT, MF_BYCOMMAND | MF_STRING | MF_GRAYED, 
               ID_TRAY_TUNNEL_DISCONNECT, L"Disconnect Tunnel");
    ModifyMenu(g_menu, ID_TRAY_TUNNEL_STATUS, MF_BYCOMMAND | MF_STRING, 
               ID_TRAY_TUNNEL_STATUS, L"Tunnel: Disconnected");
    ModifyMenu(g_menu, ID_TRAY_TUNNEL_COPY_URL, MF_BYCOMMAND | MF_STRING | MF_GRAYED, 
               ID_TRAY_TUNNEL_COPY_URL, L"Copy Tunnel URL");
  }
  
  // Show the menu
  SetForegroundWindow(hwnd);
  TrackPopupMenu(g_menu, TPM_LEFTALIGN | TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, NULL);
  PostMessage(hwnd, WM_NULL, 0, 0);
}

// Start the LLM service (Ollama)
bool StartLlmService() {
  if (!g_channel) return g_isLlmRunning;
  
  // Call Dart method to start LLM service
  flutter::EncodableMap args;
  g_channel->InvokeMethod("startLlm", 
                         std::make_unique<flutter::EncodableValue>(args),
                         nullptr);
  
  // We can't get the result directly, so we'll assume it's starting
  // The status will be updated through the updateLlmStatus method
  return g_isLlmRunning;
}

// Check the LLM service status
bool CheckLlmStatus() {
  if (!g_channel) return g_isLlmRunning;
  
  // Call Dart method to check LLM status
  flutter::EncodableMap args;
  g_channel->InvokeMethod("checkLlmStatus", 
                         std::make_unique<flutter::EncodableValue>(args),
                         nullptr);
  
  // The status will be updated through the updateLlmStatus method
  return g_isLlmRunning;
}

// Connect the tunnel
void ConnectTunnel() {
  if (!g_channel) return;
  
  // Call Dart method to connect tunnel
  flutter::EncodableMap args;
  g_channel->InvokeMethod("connectTunnel", 
                         std::make_unique<flutter::EncodableValue>(args),
                         nullptr);
  
  // The status will be updated through the updateTunnelStatus method
}

// Disconnect the tunnel
void DisconnectTunnel() {
  if (!g_channel) return;
  
  // Call Dart method to disconnect tunnel
  flutter::EncodableMap args;
  g_channel->InvokeMethod("disconnectTunnel", 
                         std::make_unique<flutter::EncodableValue>(args),
                         nullptr);
  
  // The status will be updated through the updateTunnelStatus method
}

// Check the tunnel status
bool CheckTunnelStatus() {
  if (!g_channel) return g_isTunnelConnected;
  
  // Call Dart method to check tunnel status
  flutter::EncodableMap args;
  g_channel->InvokeMethod("checkTunnelStatus", 
                         std::make_unique<flutter::EncodableValue>(args),
                         nullptr);
  
  // The status will be updated through the updateTunnelStatus method
  return g_isTunnelConnected;
}

// Copy the tunnel URL to clipboard
void CopyTunnelUrl() {
  if (g_tunnelUrl.empty()) return;
  
  // Open clipboard
  if (!OpenClipboard(NULL)) return;
  
  // Empty clipboard
  EmptyClipboard();
  
  // Allocate global memory
  HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, g_tunnelUrl.size() + 1);
  if (!hMem) {
    CloseClipboard();
    return;
  }
  
  // Copy string to global memory
  memcpy(GlobalLock(hMem), g_tunnelUrl.c_str(), g_tunnelUrl.size() + 1);
  GlobalUnlock(hMem);
  
  // Set clipboard data
  SetClipboardData(CF_TEXT, hMem);
  
  // Close clipboard
  CloseClipboard();
}
