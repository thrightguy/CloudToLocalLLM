import { addClass, hasClass, removeClass, createElement } from '@primeuix/utils/dom';
import { uuid } from '@primeuix/utils/uuid';
import BaseDirective from '@primevue/core/basedirective';
import BadgeDirectiveStyle from 'primevue/badgedirective/style';

var BaseBadgeDirective = BaseDirective.extend({
  style: BadgeDirectiveStyle
});

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
var BadgeDirective = BaseBadgeDirective.extend('badge', {
  mounted: function mounted(el, binding) {
    console.warn('Deprecated since v4. Use OverlayBadge component instead.');
    var id = uuid('pv_id') + '_badge';
    var badge = createElement('span', _defineProperty(_defineProperty({
      id: id,
      "class": !this.isUnstyled() && this.cx('root')
    }, this.$attrSelector, ''), 'p-bind', this.ptm('root', {
      context: _objectSpread(_objectSpread({}, binding.modifiers), {}, {
        nogutter: String(binding.value).length === 1,
        dot: binding.value == null
      })
    })));
    el.$_pbadgeId = badge.getAttribute('id');
    for (var modifier in binding.modifiers) {
      !this.isUnstyled() && addClass(badge, 'p-badge-' + modifier);
    }
    if (binding.value != null) {
      if (_typeof(binding.value) === 'object') el.$_badgeValue = binding.value.value;else el.$_badgeValue = binding.value;
      badge.appendChild(document.createTextNode(el.$_badgeValue));
      if (String(el.$_badgeValue).length === 1 && !this.isUnstyled()) {
        !this.isUnstyled() && addClass(badge, 'p-badge-circle');
      }
    } else {
      !this.isUnstyled() && addClass(badge, 'p-badge-dot');
    }
    el.setAttribute('data-pd-badge', true);
    !this.isUnstyled() && addClass(el, 'p-overlay-badge');
    el.setAttribute('data-p-overlay-badge', 'true');
    el.appendChild(badge);
    this.$el = badge;
  },
  updated: function updated(el, binding) {
    !this.isUnstyled() && addClass(el, 'p-overlay-badge');
    el.setAttribute('data-p-overlay-badge', 'true');
    if (binding.oldValue !== binding.value) {
      var badge = document.getElementById(el.$_pbadgeId);
      if (_typeof(binding.value) === 'object') el.$_badgeValue = binding.value.value;else el.$_badgeValue = binding.value;
      if (!this.isUnstyled()) {
        if (el.$_badgeValue) {
          if (hasClass(badge, 'p-badge-dot')) removeClass(badge, 'p-badge-dot');
          if (el.$_badgeValue.length === 1) addClass(badge, 'p-badge-circle');else removeClass(badge, 'p-badge-circle');
        } else if (!el.$_badgeValue && !hasClass(badge, 'p-badge-dot')) {
          addClass(badge, 'p-badge-dot');
        }
      }
      badge.innerHTML = '';
      badge.appendChild(document.createTextNode(el.$_badgeValue));
    }
  }
});

export { BadgeDirective as default };
//# sourceMappingURL=index.mjs.map
