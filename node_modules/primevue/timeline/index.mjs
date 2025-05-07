import { cn } from '@primeuix/utils';
import { resolveFieldData } from '@primeuix/utils/object';
import BaseComponent from '@primevue/core/basecomponent';
import TimelineStyle from 'primevue/timeline/style';
import { createElementBlock, openBlock, mergeProps, Fragment, renderList, createElementVNode, renderSlot, createCommentVNode } from 'vue';

var script$1 = {
  name: 'BaseTimeline',
  "extends": BaseComponent,
  props: {
    value: null,
    align: {
      mode: String,
      "default": 'left'
    },
    layout: {
      mode: String,
      "default": 'vertical'
    },
    dataKey: null
  },
  style: TimelineStyle,
  provide: function provide() {
    return {
      $pcTimeline: this,
      $parentInstance: this
    };
  }
};

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var script = {
  name: 'Timeline',
  "extends": script$1,
  inheritAttrs: false,
  methods: {
    getKey: function getKey(item, index) {
      return this.dataKey ? resolveFieldData(item, this.dataKey) : index;
    },
    getPTOptions: function getPTOptions(key, index) {
      return this.ptm(key, {
        context: {
          index: index,
          count: this.value.length
        }
      });
    }
  },
  computed: {
    dataP: function dataP() {
      return cn(_defineProperty(_defineProperty({}, this.layout, this.layout), this.align, this.align));
    }
  }
};

var _hoisted_1 = ["data-p"];
var _hoisted_2 = ["data-p"];
var _hoisted_3 = ["data-p"];
var _hoisted_4 = ["data-p"];
var _hoisted_5 = ["data-p"];
var _hoisted_6 = ["data-p"];
var _hoisted_7 = ["data-p"];
function render(_ctx, _cache, $props, $setup, $data, $options) {
  return openBlock(), createElementBlock("div", mergeProps({
    "class": _ctx.cx('root')
  }, _ctx.ptmi('root'), {
    "data-p": $options.dataP
  }), [(openBlock(true), createElementBlock(Fragment, null, renderList(_ctx.value, function (item, index) {
    return openBlock(), createElementBlock("div", mergeProps({
      key: $options.getKey(item, index),
      "class": _ctx.cx('event'),
      ref_for: true
    }, $options.getPTOptions('event', index), {
      "data-p": $options.dataP
    }), [createElementVNode("div", mergeProps({
      "class": _ctx.cx('eventOpposite', {
        index: index
      }),
      ref_for: true
    }, $options.getPTOptions('eventOpposite', index), {
      "data-p": $options.dataP
    }), [renderSlot(_ctx.$slots, "opposite", {
      item: item,
      index: index
    })], 16, _hoisted_3), createElementVNode("div", mergeProps({
      "class": _ctx.cx('eventSeparator'),
      ref_for: true
    }, $options.getPTOptions('eventSeparator', index), {
      "data-p": $options.dataP
    }), [renderSlot(_ctx.$slots, "marker", {
      item: item,
      index: index
    }, function () {
      return [createElementVNode("div", mergeProps({
        "class": _ctx.cx('eventMarker'),
        ref_for: true
      }, $options.getPTOptions('eventMarker', index), {
        "data-p": $options.dataP
      }), null, 16, _hoisted_5)];
    }), index !== _ctx.value.length - 1 ? renderSlot(_ctx.$slots, "connector", {
      key: 0,
      item: item,
      index: index
    }, function () {
      return [createElementVNode("div", mergeProps({
        "class": _ctx.cx('eventConnector'),
        ref_for: true
      }, $options.getPTOptions('eventConnector', index), {
        "data-p": $options.dataP
      }), null, 16, _hoisted_6)];
    }) : createCommentVNode("", true)], 16, _hoisted_4), createElementVNode("div", mergeProps({
      "class": _ctx.cx('eventContent'),
      ref_for: true
    }, $options.getPTOptions('eventContent', index), {
      "data-p": $options.dataP
    }), [renderSlot(_ctx.$slots, "content", {
      item: item,
      index: index
    })], 16, _hoisted_7)], 16, _hoisted_2);
  }), 128))], 16, _hoisted_1);
}

script.render = render;

export { script as default };
//# sourceMappingURL=index.mjs.map
