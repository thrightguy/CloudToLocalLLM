#include "include/tray_manager/tray_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <libayatana-appindicator/app-indicator.h>

#include <cstring>

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

static AppIndicator* indicator;
static GtkWidget* menu;

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
  if (indicator) {
    g_object_unref(indicator);
    indicator = nullptr;
  }

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_icon(TrayManagerPlugin* self, FlValue* args) {
  const char* icon_path =
      fl_value_get_string(fl_value_lookup_string(args, "iconPath"));
  const char* id = "tray_manager";

  if (!menu)
    menu = gtk_menu_new();

  if (!indicator) {
    // Use modern GObject constructor instead of deprecated app_indicator_new
    indicator = APP_INDICATOR(g_object_new(APP_INDICATOR_TYPE,
                                          "id", id,
                                          "icon-name", icon_path,
                                          "category", APP_INDICATOR_CATEGORY_APPLICATION_STATUS,
                                          NULL));

    app_indicator_set_menu(indicator, GTK_MENU(menu));
    gtk_widget_show_all(menu);
  }

  app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
  app_indicator_set_icon_full(indicator, icon_path, "");

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_title(TrayManagerPlugin* self, FlValue* args) {
  const char* title =
      fl_value_get_string(fl_value_lookup_string(args, "title"));

  app_indicator_set_label(indicator, title, NULL);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_context_menu(TrayManagerPlugin* self,
                                          FlValue* args) {
  menu = _create_menu(fl_value_lookup_string(args, "menu"));

  app_indicator_set_menu(indicator, GTK_MENU(menu));
  gtk_widget_show_all(menu);

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
