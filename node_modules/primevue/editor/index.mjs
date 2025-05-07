import { isExist } from '@primeuix/utils/dom';
import BaseEditableHolder from '@primevue/core/baseeditableholder';
import EditorStyle from 'primevue/editor/style';
import { createElementBlock, openBlock, mergeProps, createElementVNode, renderSlot, normalizeProps, guardReactiveProps } from 'vue';

var script$1 = {
  name: 'BaseEditor',
  "extends": BaseEditableHolder,
  props: {
    placeholder: String,
    readonly: Boolean,
    formats: Array,
    editorStyle: null,
    modules: null
  },
  style: EditorStyle,
  provide: function provide() {
    return {
      $pcEditor: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var QuillJS = function () {
  try {
    return window.Quill;
  } catch (_unused) {
    return null;
  }
}();
var script = {
  name: 'Editor',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['text-change', 'selection-change', 'load'],
  quill: null,
  watch: {
    modelValue: function modelValue(newValue, oldValue) {
      if (newValue !== oldValue && this.quill && !this.quill.hasFocus()) {
        this.renderValue(newValue);
      }
    },
    readonly: function readonly() {
      this.handleReadOnlyChange();
    }
  },
  mounted: function mounted() {
    var _this = this;
    var configuration = {
      modules: _objectSpread({
        toolbar: this.$refs.toolbarElement
      }, this.modules),
      readOnly: this.readonly,
      theme: 'snow',
      formats: this.formats,
      placeholder: this.placeholder
    };
    if (QuillJS) {
      // Loaded by script only
      this.quill = new QuillJS(this.$refs.editorElement, configuration);
      this.initQuill();
      this.handleLoad();
    } else {
      import('quill').then(function (module) {
        if (module && isExist(_this.$refs.editorElement)) {
          if (module["default"]) {
            // webpack
            _this.quill = new module["default"](_this.$refs.editorElement, configuration);
          } else {
            // parceljs
            _this.quill = new module(_this.$refs.editorElement, configuration);
          }
          _this.initQuill();
        }
      }).then(function () {
        _this.handleLoad();
      });
    }
  },
  beforeUnmount: function beforeUnmount() {
    this.quill = null;
  },
  methods: {
    renderValue: function renderValue(value) {
      if (this.quill) {
        if (value) {
          var delta = this.quill.clipboard.convert({
            html: value
          });
          this.quill.setContents(delta);
        } else {
          this.quill.setText('');
        }
      }
    },
    initQuill: function initQuill() {
      var _this2 = this;
      this.renderValue(this.d_value);
      this.quill.on('text-change', function (delta, oldContents, source) {
        if (source === 'user') {
          var html = _this2.quill.getSemanticHTML();
          var text = _this2.quill.getText().trim();
          if (html === '<p><br></p>') {
            html = '';
          }
          _this2.writeValue(html);
          _this2.$emit('text-change', {
            htmlValue: html,
            textValue: text,
            delta: delta,
            source: source,
            instance: _this2.quill
          });
        }
      });
      this.quill.on('selection-change', function (range, oldRange, source) {
        var html = _this2.quill.getSemanticHTML();
        var text = _this2.quill.getText().trim();
        _this2.$emit('selection-change', {
          htmlValue: html,
          textValue: text,
          range: range,
          oldRange: oldRange,
          source: source,
          instance: _this2.quill
        });
      });
    },
    handleLoad: function handleLoad() {
      if (this.quill && this.quill.getModule('toolbar')) {
        this.$emit('load', {
          instance: this.quill
        });
      }
    },
    handleReadOnlyChange: function handleReadOnlyChange() {
      if (this.quill) this.quill.enable(!this.readonly);
    }
  }
};

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root')
  }, _ctx.ptmi('root')), [createElementVNode("div", mergeProps({
    ref: "toolbarElement",
    "class": _ctx.cx('toolbar')
  }, _ctx.ptm('toolbar')), [renderSlot(_ctx.$slots, "toolbar", {}, function () {
    return [createElementVNode("span", mergeProps({
      "class": "ql-formats"
    }, _ctx.ptm('formats')), [createElementVNode("select", mergeProps({
      "class": "ql-header",
      defaultValue: "0"
    }, _ctx.ptm('header')), [createElementVNode("option", mergeProps({
      value: "1"
    }, _ctx.ptm('option')), "Heading", 16), createElementVNode("option", mergeProps({
      value: "2"
    }, _ctx.ptm('option')), "Subheading", 16), createElementVNode("option", mergeProps({
      value: "0"
    }, _ctx.ptm('option')), "Normal", 16)], 16), createElementVNode("select", mergeProps({
      "class": "ql-font"
    }, _ctx.ptm('font')), [createElementVNode("option", normalizeProps(guardReactiveProps(_ctx.ptm('option'))), null, 16), createElementVNode("option", mergeProps({
      value: "serif"
    }, _ctx.ptm('option')), null, 16), createElementVNode("option", mergeProps({
      value: "monospace"
    }, _ctx.ptm('option')), null, 16)], 16)], 16), createElementVNode("span", mergeProps({
      "class": "ql-formats"
    }, _ctx.ptm('formats')), [createElementVNode("button", mergeProps({
      "class": "ql-bold",
      type: "button"
    }, _ctx.ptm('bold')), null, 16), createElementVNode("button", mergeProps({
      "class": "ql-italic",
      type: "button"
    }, _ctx.ptm('italic')), null, 16), createElementVNode("button", mergeProps({
      "class": "ql-underline",
      type: "button"
    }, _ctx.ptm('underline')), null, 16)], 16), createElementVNode("span", mergeProps({
      "class": "ql-formats"
    }, _ctx.ptm('formats')), [createElementVNode("select", mergeProps({
      "class": "ql-color"
    }, _ctx.ptm('color')), null, 16), createElementVNode("select", mergeProps({
      "class": "ql-background"
    }, _ctx.ptm('background')), null, 16)], 16), createElementVNode("span", mergeProps({
      "class": "ql-formats"
    }, _ctx.ptm('formats')), [createElementVNode("button", mergeProps({
      "class": "ql-list",
      value: "ordered",
      type: "button"
    }, _ctx.ptm('list')), null, 16), createElementVNode("button", mergeProps({
      "class": "ql-list",
      value: "bullet",
      type: "button"
    }, _ctx.ptm('list')), null, 16), createElementVNode("select", mergeProps({
      "class": "ql-align"
    }, _ctx.ptm('select')), [createElementVNode("option", mergeProps({
      defaultValue: ""
    }, _ctx.ptm('option')), null, 16), createElementVNode("option", mergeProps({
      value: "center"
    }, _ctx.ptm('option')), null, 16), createElementVNode("option", mergeProps({
      value: "right"
    }, _ctx.ptm('option')), null, 16), createElementVNode("option", mergeProps({
      value: "justify"
    }, _ctx.ptm('option')), null, 16)], 16)], 16), createElementVNode("span", mergeProps({
      "class": "ql-formats"
    }, _ctx.ptm('formats')), [createElementVNode("button", mergeProps({
      "class": "ql-link",
      type: "button"
    }, _ctx.ptm('link')), null, 16), createElementVNode("button", mergeProps({
      "class": "ql-image",
      type: "button"
    }, _ctx.ptm('image')), null, 16), createElementVNode("button", mergeProps({
      "class": "ql-code-block",
      type: "button"
    }, _ctx.ptm('codeBlock')), null, 16)], 16), createElementVNode("span", mergeProps({
      "class": "ql-formats"
    }, _ctx.ptm('formats')), [createElementVNode("button", mergeProps({
      "class": "ql-clean",
      type: "button"
    }, _ctx.ptm('clean')), null, 16)], 16)];
  })], 16), createElementVNode("div", mergeProps({
    ref: "editorElement",
    "class": _ctx.cx('content'),
    style: _ctx.editorStyle
  }, _ctx.ptm('content')), null, 16)], 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
