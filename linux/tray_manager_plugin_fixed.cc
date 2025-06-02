#include "include/tray_manager/tray_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <libayatana-appindicator/app-indicator.h>
#include <glib.h>
#include <gio/gio.h>

#include <cstring>
#include <unistd.h>
#include <sys/stat.h>

#define TRAY_MANAGER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), tray_manager_plugin_get_type(), \
                               TrayManagerPlugin))

struct _TrayManagerPlugin {
  GObject parent_instance;

  FlPluginRegistrar* registrar;

  FlMethodChannel* channel;
};

G_DEFINE_TYPE(TrayManagerPlugin, tray_manager_plugin, g_object_get_type())

static TrayManagerPlugin* plugin_instance;

static AppIndicator* indicator = nullptr;
static GtkWidget* menu = nullptr;
static gboolean tray_initialized = FALSE;

// Helper function to check if a file exists and is readable
static gboolean file_exists_and_readable(const char* path) {
  if (!path || strlen(path) == 0) {
    return FALSE;
  }

  struct stat st;
  return (stat(path, &st) == 0 && S_ISREG(st.st_mode) && access(path, R_OK) == 0);
}

// Helper function to validate icon path and find fallback
static const char* validate_and_get_icon_path(const char* requested_path) {
  // First try the requested path
  if (requested_path && file_exists_and_readable(requested_path)) {
    g_debug("Using requested icon path: %s", requested_path);
    return requested_path;
  }

  // Try common fallback paths
  const char* fallback_paths[] = {
    "data/flutter_assets/assets/images/tray_icon_contrast_16.png",
    "data/flutter_assets/assets/images/tray_icon_16.png",
    "data/flutter_assets/assets/images/app_icon.png",
    "/usr/share/pixmaps/cloudtolocalllm.png",
    "/usr/share/icons/hicolor/16x16/apps/cloudtolocalllm.png",
    nullptr
  };

  for (int i = 0; fallback_paths[i] != nullptr; i++) {
    if (file_exists_and_readable(fallback_paths[i])) {
      g_debug("Using fallback icon path: %s", fallback_paths[i]);
      return fallback_paths[i];
    }
  }

  // If no file-based icon works, return a system icon name
  g_warning("No valid icon file found, using system icon");
  return "application-x-executable";
}

// Helper function to safely create and initialize AppIndicator
static gboolean ensure_indicator_created(const char* icon_path) {
  if (indicator != nullptr) {
    return TRUE; // Already created
  }

  const char* validated_icon = validate_and_get_icon_path(icon_path);
  if (!validated_icon) {
    g_error("Failed to find any valid icon for system tray");
    return FALSE;
  }

  // Create the indicator with proper error handling
  indicator = APP_INDICATOR(g_object_new(APP_INDICATOR_TYPE,
                                        "id", "cloudtolocalllm-tray",
                                        "icon-name", validated_icon,
                                        "category", APP_INDICATOR_CATEGORY_APPLICATION_STATUS,
                                        "status", APP_INDICATOR_STATUS_PASSIVE,
                                        nullptr));

  if (!indicator) {
    g_error("Failed to create AppIndicator instance");
    return FALSE;
  }

  g_debug("AppIndicator created successfully with icon: %s", validated_icon);
  return TRUE;
}

// Helper function to safely create menu
static gboolean ensure_menu_created() {
  if (menu != nullptr) {
    return TRUE; // Already created
  }

  menu = gtk_menu_new();
  if (!menu) {
    g_error("Failed to create GTK menu for system tray");
    return FALSE;
  }

  g_debug("GTK menu created successfully");
  return TRUE;
}

static void _menu_item_activated(GtkMenuItem* menuitem, gpointer user_data) {
  const char* id = (const char*)g_object_get_data(G_OBJECT(menuitem), "id");

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(id));

  fl_method_channel_invoke_method(plugin_instance->channel, "onMenuItemClick",
                                  args, nullptr, nullptr, nullptr);
}

static GtkWidget* _create_menu_item(FlValue* item) {
  const char* id = fl_value_get_string(fl_value_lookup_string(item, "id"));
  const char* label =
      fl_value_get_string(fl_value_lookup_string(item, "label"));
  const char* type = fl_value_get_string(fl_value_lookup_string(item, "type"));
  bool disabled = fl_value_get_bool(fl_value_lookup_string(item, "disabled"));
  bool checked = fl_value_get_bool(fl_value_lookup_string(item, "checked"));

  GtkWidget* menu_item;

  if (strcmp(type, "separator") == 0) {
    menu_item = gtk_separator_menu_item_new();
  } else if (strcmp(type, "checkbox") == 0) {
    menu_item = gtk_check_menu_item_new_with_label(label);
    gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(menu_item), checked);
  } else {
    menu_item = gtk_menu_item_new_with_label(label);
  }

  gtk_widget_set_sensitive(menu_item, !disabled);

  g_object_set_data_full(G_OBJECT(menu_item), "id", g_strdup(id), g_free);

  g_signal_connect(menu_item, "activate", G_CALLBACK(_menu_item_activated),
                   nullptr);

  return menu_item;
}

static GtkWidget* _create_menu(FlValue* menu_value) {
  GtkWidget* menu = gtk_menu_new();

  for (size_t i = 0; i < fl_value_get_length(menu_value); i++) {
    FlValue* item = fl_value_get_list_value(menu_value, i);
    GtkWidget* menu_item = _create_menu_item(item);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), menu_item);
  }

  return menu;
}

static FlMethodResponse* destroy(TrayManagerPlugin* self, FlValue* args) {
  g_debug("Destroying system tray components");

  // Destroy menu first
  if (menu) {
    gtk_widget_destroy(menu);
    menu = nullptr;
    g_debug("System tray menu destroyed");
  }

  // Destroy indicator
  if (indicator) {
    app_indicator_set_status(indicator, APP_INDICATOR_STATUS_PASSIVE);
    g_object_unref(indicator);
    indicator = nullptr;
    g_debug("System tray indicator destroyed");
  }

  tray_initialized = FALSE;
  g_debug("System tray cleanup completed");

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_icon(TrayManagerPlugin* self, FlValue* args) {
  // Validate input parameters
  if (!args) {
    g_warning("set_icon called with null args");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGS", "Arguments cannot be null", nullptr));
  }

  FlValue* icon_path_value = fl_value_lookup_string(args, "iconPath");
  if (!icon_path_value) {
    g_warning("set_icon called without iconPath parameter");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("MISSING_ICON_PATH", "iconPath parameter is required", nullptr));
  }

  const char* icon_path = fl_value_get_string(icon_path_value);
  if (!icon_path) {
    g_warning("set_icon called with invalid iconPath value");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ICON_PATH", "iconPath must be a string", nullptr));
  }

  g_debug("Setting system tray icon to: %s", icon_path);

  // Ensure menu is created first
  if (!ensure_menu_created()) {
    g_error("Failed to create menu for system tray");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("MENU_CREATION_FAILED", "Failed to create system tray menu", nullptr));
  }

  // Ensure indicator is created
  if (!ensure_indicator_created(icon_path)) {
    g_error("Failed to create AppIndicator");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INDICATOR_CREATION_FAILED", "Failed to create system tray indicator", nullptr));
  }

  // Set the menu on the indicator
  app_indicator_set_menu(indicator, GTK_MENU(menu));
  gtk_widget_show_all(menu);

  // Update the icon with validation
  const char* validated_icon = validate_and_get_icon_path(icon_path);
  if (validated_icon) {
    app_indicator_set_icon_full(indicator, validated_icon, "CloudToLocalLLM");
    g_debug("System tray icon updated to: %s", validated_icon);
  } else {
    g_warning("Failed to validate icon path, keeping current icon");
  }

  // Activate the indicator
  app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
  tray_initialized = TRUE;

  g_debug("System tray icon set successfully");
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_title(TrayManagerPlugin* self, FlValue* args) {
  // Validate input parameters
  if (!args) {
    g_warning("set_title called with null args");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGS", "Arguments cannot be null", nullptr));
  }

  // Check if indicator exists
  if (!indicator) {
    g_warning("set_title called before indicator was created");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("NO_INDICATOR", "System tray indicator not initialized", nullptr));
  }

  FlValue* title_value = fl_value_lookup_string(args, "title");
  if (!title_value) {
    g_warning("set_title called without title parameter");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("MISSING_TITLE", "title parameter is required", nullptr));
  }

  const char* title = fl_value_get_string(title_value);
  if (!title) {
    g_warning("set_title called with invalid title value");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_TITLE", "title must be a string", nullptr));
  }

  g_debug("Setting system tray title to: %s", title);
  app_indicator_set_label(indicator, title, nullptr);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_context_menu(TrayManagerPlugin* self,
                                          FlValue* args) {
  // Validate input parameters
  if (!args) {
    g_warning("set_context_menu called with null args");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGS", "Arguments cannot be null", nullptr));
  }

  // Check if indicator exists
  if (!indicator) {
    g_warning("set_context_menu called before indicator was created");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("NO_INDICATOR", "System tray indicator not initialized", nullptr));
  }

  FlValue* menu_value = fl_value_lookup_string(args, "menu");
  if (!menu_value) {
    g_warning("set_context_menu called without menu parameter");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("MISSING_MENU", "menu parameter is required", nullptr));
  }

  g_debug("Creating system tray context menu");

  // Destroy existing menu if it exists
  if (menu) {
    gtk_widget_destroy(menu);
    menu = nullptr;
  }

  // Create new menu
  menu = _create_menu(menu_value);
  if (!menu) {
    g_error("Failed to create context menu");
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("MENU_CREATION_FAILED", "Failed to create context menu", nullptr));
  }

  // Set the menu on the indicator
  app_indicator_set_menu(indicator, GTK_MENU(menu));
  gtk_widget_show_all(menu);

  g_debug("System tray context menu set successfully");
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

// Called when a method call is received from Flutter.
static void tray_manager_plugin_handle_method_call(TrayManagerPlugin* self,
                                                   FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "destroy") == 0) {
    response = destroy(self, args);
  } else if (strcmp(method, "setIcon") == 0) {
    response = set_icon(self, args);
  } else if (strcmp(method, "setTitle") == 0) {
    response = set_title(self, args);
  } else if (strcmp(method, "setContextMenu") == 0) {
    response = set_context_menu(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void tray_manager_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(tray_manager_plugin_parent_class)->dispose(object);
}

static void tray_manager_plugin_class_init(TrayManagerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = tray_manager_plugin_dispose;
}

static void tray_manager_plugin_init(TrayManagerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(user_data);
  tray_manager_plugin_handle_method_call(plugin, method_call);
}

void tray_manager_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(
      g_object_new(tray_manager_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "tray_manager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  plugin_instance = plugin;

  g_object_unref(plugin);
}
