import { getAttribute, removeClass, getHeight, getWidth, getOuterWidth, getOuterHeight, getOffset, addClass, createElement } from '@primeuix/utils/dom';
import BaseDirective from '@primevue/core/basedirective';
import RippleStyle from 'primevue/ripple/style';

var BaseRipple = BaseDirective.extend({
  style: RippleStyle
});

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _toConsumableArray(r) { return _arrayWithoutHoles(r) || _iterableToArray(r) || _unsupportedIterableToArray(r) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _iterableToArray(r) { if ("undefined" != typeof Symbol && null != r[Symbol.iterator] || null != r["@@iterator"]) return Array.from(r); }
function _arrayWithoutHoles(r) { if (Array.isArray(r)) return _arrayLikeToArray(r); }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var Ripple = BaseRipple.extend('ripple', {
  watch: {
    'config.ripple': function configRipple(newValue) {
      if (newValue) {
        this.createRipple(this.$host);
        this.bindEvents(this.$host);
        this.$host.setAttribute('data-pd-ripple', true);
        this.$host.style['overflow'] = 'hidden';
        this.$host.style['position'] = 'relative';
      } else {
        this.remove(this.$host);
        this.$host.removeAttribute('data-pd-ripple');
      }
    }
  },
  unmounted: function unmounted(el) {
    this.remove(el);
  },
  timeout: undefined,
  methods: {
    bindEvents: function bindEvents(el) {
      el.addEventListener('mousedown', this.onMouseDown.bind(this));
    },
    unbindEvents: function unbindEvents(el) {
      el.removeEventListener('mousedown', this.onMouseDown.bind(this));
    },
    createRipple: function createRipple(el) {
      var ink = this.getInk(el);
      if (!ink) {
        ink = createElement('span', _defineProperty(_defineProperty({
          role: 'presentation',
          'aria-hidden': true,
          'data-p-ink': true,
          'data-p-ink-active': false,
          "class": !this.isUnstyled() && this.cx('root'),
          onAnimationEnd: this.onAnimationEnd.bind(this)
        }, this.$attrSelector, ''), 'p-bind', this.ptm('root')));
        el.appendChild(ink);
        this.$el = ink;
      }
    },
    remove: function remove(el) {
      var ink = this.getInk(el);
      if (ink) {
        this.$host.style['overflow'] = '';
        this.$host.style['position'] = '';
        this.unbindEvents(el);
        ink.removeEventListener('animationend', this.onAnimationEnd);
        ink.remove();
      }
    },
    onMouseDown: function onMouseDown(event) {
      var _this = this;
      var target = event.currentTarget;
      var ink = this.getInk(target);
      if (!ink || getComputedStyle(ink, null).display === 'none') {
        return;
      }
      !this.isUnstyled() && removeClass(ink, 'p-ink-active');
      ink.setAttribute('data-p-ink-active', 'false');
      if (!getHeight(ink) && !getWidth(ink)) {
        var d = Math.max(getOuterWidth(target), getOuterHeight(target));
        ink.style.height = d + 'px';
        ink.style.width = d + 'px';
      }
      var offset = getOffset(target);
      var x = event.pageX - offset.left + document.body.scrollTop - getWidth(ink) / 2;
      var y = event.pageY - offset.top + document.body.scrollLeft - getHeight(ink) / 2;
      ink.style.top = y + 'px';
      ink.style.left = x + 'px';
      !this.isUnstyled() && addClass(ink, 'p-ink-active');
      ink.setAttribute('data-p-ink-active', 'true');
      this.timeout = setTimeout(function () {
        if (ink) {
          !_this.isUnstyled() && removeClass(ink, 'p-ink-active');
          ink.setAttribute('data-p-ink-active', 'false');
        }
      }, 401);
    },
    onAnimationEnd: function onAnimationEnd(event) {
      if (this.timeout) {
        clearTimeout(this.timeout);
      }
      !this.isUnstyled() && removeClass(event.currentTarget, 'p-ink-active');
      event.currentTarget.setAttribute('data-p-ink-active', 'false');
    },
    getInk: function getInk(el) {
      return el && el.children ? _toConsumableArray(el.children).find(function (child) {
        return getAttribute(child, 'data-pc-name') === 'ripple';
      }) : undefined;
    }
  }
});

export { Ripple as default };
//# sourceMappingURL=index.mjs.map
