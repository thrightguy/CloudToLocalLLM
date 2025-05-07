import { setAttribute, findSingle, find, scrollInView } from '@primeuix/utils/dom';
import { isNotEmpty, findIndexInList } from '@primeuix/utils/object';
import AngleDoubleDownIcon from '@primevue/icons/angledoubledown';
import AngleDoubleUpIcon from '@primevue/icons/angledoubleup';
import AngleDownIcon from '@primevue/icons/angledown';
import AngleUpIcon from '@primevue/icons/angleup';
import Button from 'primevue/button';
import Listbox from 'primevue/listbox';
import Ripple from 'primevue/ripple';
import BaseComponent from '@primevue/core/basecomponent';
import OrderListStyle from 'primevue/orderlist/style';
import { resolveComponent, createElementBlock, openBlock, mergeProps, createElementVNode, createVNode, renderSlot, withCtx, createSlots } from 'vue';

var script$1 = {
  name: 'BaseOrderList',
  "extends": BaseComponent,
  props: {
    modelValue: {
      type: Array,
      "default": null
    },
    selection: {
      type: Array,
      "default": null
    },
    dataKey: {
      type: String,
      "default": null
    },
    listStyle: {
      type: null,
      "default": null
    },
    metaKeySelection: {
      type: Boolean,
      "default": false
    },
    autoOptionFocus: {
      type: Boolean,
      "default": true
    },
    focusOnHover: {
      type: Boolean,
      "default": true
    },
    responsive: {
      type: Boolean,
      "default": true
    },
    breakpoint: {
      type: String,
      "default": '960px'
    },
    striped: {
      type: Boolean,
      "default": false
    },
    scrollHeight: {
      type: String,
      "default": '14rem'
    },
    buttonProps: {
      type: Object,
      "default": function _default() {
        return {
          severity: 'secondary'
        };
      }
    },
    moveUpButtonProps: {
      type: null,
      "default": null
    },
    moveTopButtonProps: {
      type: null,
      "default": null
    },
    moveDownButtonProps: {
      type: null,
      "default": null
    },
    moveBottomButtonProps: {
      type: null,
      "default": null
    },
    tabindex: {
      type: Number,
      "default": 0
    },
    disabled: {
      type: Boolean,
      "default": false
    },
    ariaLabelledby: {
      type: String,
      "default": null
    },
    ariaLabel: {
      type: String,
      "default": null
    }
  },
  style: OrderListStyle,
  provide: function provide() {
    return {
      $pcOrderList: this,
      $parentInstance: this
    };
  }
};

function _toConsumableArray(r) { return _arrayWithoutHoles(r) || _iterableToArray(r) || _unsupportedIterableToArray(r) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _iterableToArray(r) { if ("undefined" != typeof Symbol && null != r[Symbol.iterator] || null != r["@@iterator"]) return Array.from(r); }
function _arrayWithoutHoles(r) { if (Array.isArray(r)) return _arrayLikeToArray(r); }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
var script = {
  name: 'OrderList',
  "extends": script$1,
  inheritAttrs: false,
  emits: ['update:modelValue', 'reorder', 'update:selection', 'selection-change', 'focus', 'blur'],
  itemTouched: false,
  reorderDirection: null,
  styleElement: null,
  list: null,
  data: function data() {
    return {
      d_selection: this.selection
    };
  },
  beforeUnmount: function beforeUnmount() {
    this.destroyStyle();
  },
  updated: function updated() {
    if (this.reorderDirection) {
      this.updateListScroll();
      this.reorderDirection = null;
    }
  },
  mounted: function mounted() {
    if (this.responsive) {
      this.createStyle();
    }
  },
  methods: {
    updateSelection: function updateSelection(event) {
      this.$emit('update:selection', this.d_selection);
      this.$emit('selection-change', {
        originalEvent: event,
        value: this.d_selection
      });
    },
    onChangeSelection: function onChangeSelection(params) {
      this.d_selection = params.value;
      this.updateSelection(params.event);
    },
    onListFocus: function onListFocus(event) {
      this.$emit('focus', event);
    },
    onListBlur: function onListBlur(event) {
      this.$emit('blur', event);
    },
    onReorderUpdate: function onReorderUpdate(event, value) {
      this.$emit('update:modelValue', value);
      this.$emit('reorder', {
        originalEvent: event,
        value: value,
        direction: this.reorderDirection
      });
    },
    moveUp: function moveUp(event) {
      if (this.d_selection) {
        var value = _toConsumableArray(this.modelValue);
        for (var i = 0; i < this.d_selection.length; i++) {
          var selectedItem = this.d_selection[i];
          var selectedItemIndex = findIndexInList(selectedItem, value);
          if (selectedItemIndex !== 0) {
            var movedItem = value[selectedItemIndex];
            var temp = value[selectedItemIndex - 1];
            value[selectedItemIndex - 1] = movedItem;
            value[selectedItemIndex] = temp;
          } else {
            break;
          }
        }
        this.reorderDirection = 'up';
        this.onReorderUpdate(event, value);
      }
    },
    moveTop: function moveTop(event) {
      if (this.d_selection) {
        var value = _toConsumableArray(this.modelValue);
        for (var i = 0; i < this.d_selection.length; i++) {
          var selectedItem = this.d_selection[i];
          var selectedItemIndex = findIndexInList(selectedItem, value);
          if (selectedItemIndex !== 0) {
            var movedItem = value.splice(selectedItemIndex, 1)[0];
            value.unshift(movedItem);
          } else {
            break;
          }
        }
        this.reorderDirection = 'top';
        this.onReorderUpdate(event, value);
      }
    },
    moveDown: function moveDown(event) {
      if (this.d_selection) {
        var value = _toConsumableArray(this.modelValue);
        for (var i = this.d_selection.length - 1; i >= 0; i--) {
          var selectedItem = this.d_selection[i];
          var selectedItemIndex = findIndexInList(selectedItem, value);
          if (selectedItemIndex !== value.length - 1) {
            var movedItem = value[selectedItemIndex];
            var temp = value[selectedItemIndex + 1];
            value[selectedItemIndex + 1] = movedItem;
            value[selectedItemIndex] = temp;
          } else {
            break;
          }
        }
        this.reorderDirection = 'down';
        this.onReorderUpdate(event, value);
      }
    },
    moveBottom: function moveBottom(event) {
      if (this.d_selection) {
        var value = _toConsumableArray(this.modelValue);
        for (var i = this.d_selection.length - 1; i >= 0; i--) {
          var selectedItem = this.d_selection[i];
          var selectedItemIndex = findIndexInList(selectedItem, value);
          if (selectedItemIndex !== value.length - 1) {
            var movedItem = value.splice(selectedItemIndex, 1)[0];
            value.push(movedItem);
          } else {
            break;
          }
        }
        this.reorderDirection = 'bottom';
        this.onReorderUpdate(event, value);
      }
    },
    updateListScroll: function updateListScroll() {
      this.list = findSingle(this.$refs.listbox.$el, '[data-pc-section="list"]');
      var listItems = find(this.list, '[data-pc-section="item"][data-p-selected="true"]');
      if (listItems && listItems.length) {
        switch (this.reorderDirection) {
          case 'up':
            scrollInView(this.list, listItems[0]);
            break;
          case 'top':
            this.list.scrollTop = 0;
            break;
          case 'down':
            scrollInView(this.list, listItems[listItems.length - 1]);
            break;
          case 'bottom':
            this.list.scrollTop = this.list.scrollHeight;
            break;
        }
      }
    },
    createStyle: function createStyle() {
      if (!this.styleElement && !this.isUnstyled) {
        var _this$$primevue;
        this.styleElement = document.createElement('style');
        this.styleElement.type = 'text/css';
        setAttribute(this.styleElement, 'nonce', (_this$$primevue = this.$primevue) === null || _this$$primevue === void 0 || (_this$$primevue = _this$$primevue.config) === null || _this$$primevue === void 0 || (_this$$primevue = _this$$primevue.csp) === null || _this$$primevue === void 0 ? void 0 : _this$$primevue.nonce);
        document.head.appendChild(this.styleElement);
        var innerHTML = "\n@media screen and (max-width: ".concat(this.breakpoint, ") {\n    .p-orderlist[").concat(this.$attrSelector, "] {\n        flex-direction: column;\n    }\n\n    .p-orderlist[").concat(this.$attrSelector, "] .p-orderlist-controls {\n        flex-direction: row;\n    }\n}\n");
        this.styleElement.innerHTML = innerHTML;
      }
    },
    destroyStyle: function destroyStyle() {
      if (this.styleElement) {
        document.head.removeChild(this.styleElement);
        this.styleElement = null;
      }
    },
    moveDisabled: function moveDisabled() {
      return this.disabled ? true : !this.d_selection || !this.d_selection.length ? true : false;
    }
  },
  computed: {
    moveUpAriaLabel: function moveUpAriaLabel() {
      return this.$primevue.config.locale.aria ? this.$primevue.config.locale.aria.moveUp : undefined;
    },
    moveTopAriaLabel: function moveTopAriaLabel() {
      return this.$primevue.config.locale.aria ? this.$primevue.config.locale.aria.moveTop : undefined;
    },
    moveDownAriaLabel: function moveDownAriaLabel() {
      return this.$primevue.config.locale.aria ? this.$primevue.config.locale.aria.moveDown : undefined;
    },
    moveBottomAriaLabel: function moveBottomAriaLabel() {
      return this.$primevue.config.locale.aria ? this.$primevue.config.locale.aria.moveBottom : undefined;
    },
    hasSelectedOption: function hasSelectedOption() {
      return isNotEmpty(this.d_selection);
    }
  },
  components: {
    Listbox: Listbox,
    Button: Button,
    AngleUpIcon: AngleUpIcon,
    AngleDownIcon: AngleDownIcon,
    AngleDoubleUpIcon: AngleDoubleUpIcon,
    AngleDoubleDownIcon: AngleDoubleDownIcon
  },
  directives: {
    ripple: Ripple
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function render(_ctx, _cache, $props, $setup, $data, $options) {
  var _component_AngleUpIcon = resolveComponent("AngleUpIcon");
  var _component_Button = resolveComponent("Button");
  var _component_AngleDoubleUpIcon = resolveComponent("AngleDoubleUpIcon");
  var _component_AngleDownIcon = resolveComponent("AngleDownIcon");
  var _component_AngleDoubleDownIcon = resolveComponent("AngleDoubleDownIcon");
  var _component_Listbox = resolveComponent("Listbox");
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root')
  }, _ctx.ptmi('root')), [createElementVNode("div", mergeProps({
    "class": _ctx.cx('controls')
  }, _ctx.ptm('controls')), [renderSlot(_ctx.$slots, "controlsstart"), createVNode(_component_Button, mergeProps({
    onClick: $options.moveUp,
    "aria-label": $options.moveUpAriaLabel,
    disabled: $options.moveDisabled()
  }, _objectSpread(_objectSpread({}, _ctx.buttonProps), _ctx.moveUpButtonProps), {
    pt: _ctx.ptm('pcMoveUpButton'),
    unstyled: _ctx.unstyled
  }), {
    icon: withCtx(function () {
      return [renderSlot(_ctx.$slots, "moveupicon", {}, function () {
        return [createVNode(_component_AngleUpIcon, mergeProps(_ctx.ptm('pcMoveUpButton')['icon'], {
          "data-pc-section": "moveupicon"
        }), null, 16)];
      })];
    }),
    _: 3
  }, 16, ["onClick", "aria-label", "disabled", "pt", "unstyled"]), createVNode(_component_Button, mergeProps({
    onClick: $options.moveTop,
    "aria-label": $options.moveTopAriaLabel,
    disabled: $options.moveDisabled()
  }, _objectSpread(_objectSpread({}, _ctx.buttonProps), _ctx.moveTopButtonProps), {
    pt: _ctx.ptm('pcMoveTopButton'),
    unstyled: _ctx.unstyled
  }), {
    icon: withCtx(function () {
      return [renderSlot(_ctx.$slots, "movetopicon", {}, function () {
        return [createVNode(_component_AngleDoubleUpIcon, mergeProps(_ctx.ptm('pcMoveTopButton')['icon'], {
          "data-pc-section": "movetopicon"
        }), null, 16)];
      })];
    }),
    _: 3
  }, 16, ["onClick", "aria-label", "disabled", "pt", "unstyled"]), createVNode(_component_Button, mergeProps({
    onClick: $options.moveDown,
    "aria-label": $options.moveDownAriaLabel,
    disabled: $options.moveDisabled()
  }, _objectSpread(_objectSpread({}, _ctx.buttonProps), _ctx.moveDownButtonProps), {
    pt: _ctx.ptm('pcMoveDownButton'),
    unstyled: _ctx.unstyled
  }), {
    icon: withCtx(function () {
      return [renderSlot(_ctx.$slots, "movedownicon", {}, function () {
        return [createVNode(_component_AngleDownIcon, mergeProps(_ctx.ptm('pcMoveDownButton')['icon'], {
          "data-pc-section": "movedownicon"
        }), null, 16)];
      })];
    }),
    _: 3
  }, 16, ["onClick", "aria-label", "disabled", "pt", "unstyled"]), createVNode(_component_Button, mergeProps({
    onClick: $options.moveBottom,
    "aria-label": $options.moveBottomAriaLabel,
    disabled: $options.moveDisabled()
  }, _objectSpread(_objectSpread({}, _ctx.buttonProps), _ctx.moveBottomButtonProps), {
    pt: _ctx.ptm('pcMoveBottomButton'),
    unstyled: _ctx.unstyled
  }), {
    icon: withCtx(function () {
      return [renderSlot(_ctx.$slots, "movebottomicon", {}, function () {
        return [createVNode(_component_AngleDoubleDownIcon, mergeProps(_ctx.ptm('pcMoveBottomButton')['icon'], {
          "data-pc-section": "movebottomicon"
        }), null, 16)];
      })];
    }),
    _: 3
  }, 16, ["onClick", "aria-label", "disabled", "pt", "unstyled"]), renderSlot(_ctx.$slots, "controlsend")], 16), createVNode(_component_Listbox, {
    ref: "listbox",
    id: _ctx.$id,
    modelValue: $data.d_selection,
    options: _ctx.modelValue,
    multiple: "",
    metaKeySelection: _ctx.metaKeySelection,
    listStyle: _ctx.listStyle,
    scrollHeight: _ctx.scrollHeight,
    tabindex: _ctx.tabindex,
    dataKey: _ctx.dataKey,
    autoOptionFocus: _ctx.autoOptionFocus,
    focusOnHover: _ctx.focusOnHover,
    striped: _ctx.striped,
    disabled: _ctx.disabled,
    ariaLabel: _ctx.ariaLabel,
    ariaLabelledby: _ctx.ariaLabelledby,
    pt: _ctx.ptm('pcListbox'),
    unstyled: _ctx.unstyled,
    onFocus: $options.onListFocus,
    onBlur: $options.onListBlur,
    onChange: $options.onChangeSelection
  }, createSlots({
    option: withCtx(function (_ref) {
      var option = _ref.option,
        selected = _ref.selected,
        index = _ref.index;
      return [renderSlot(_ctx.$slots, _ctx.$slots.option ? 'option' : 'item', {
        item: option,
        option: option,
        selected: selected,
        index: index
      })];
    }),
    _: 2
  }, [_ctx.$slots.header ? {
    name: "header",
    fn: withCtx(function () {
      return [renderSlot(_ctx.$slots, "header")];
    }),
    key: "0"
  } : undefined]), 1032, ["id", "modelValue", "options", "metaKeySelection", "listStyle", "scrollHeight", "tabindex", "dataKey", "autoOptionFocus", "focusOnHover", "striped", "disabled", "ariaLabel", "ariaLabelledby", "pt", "unstyled", "onFocus", "onBlur", "onChange"])], 16);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
