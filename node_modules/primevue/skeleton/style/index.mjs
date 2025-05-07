import { style } from '@primeuix/styles/skeleton';
import BaseStyle from '@primevue/core/base/style';

var inlineStyles = {
  root: {
    position: 'relative'
  }
};
var classes = {
  root: function root(_ref) {
    var props = _ref.props;
    return ['p-skeleton p-component', {
      'p-skeleton-circle': props.shape === 'circle',
      'p-skeleton-animation-none': props.animation === 'none'
    }];
  }
};
var SkeletonStyle = BaseStyle.extend({
  name: 'skeleton',
  style: style,
  classes: classes,
  inlineStyles: inlineStyles
});

export { SkeletonStyle as default };
//# sourceMappingURL=index.mjs.map
