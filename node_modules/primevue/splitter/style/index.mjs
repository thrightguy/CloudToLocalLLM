import { style } from '@primeuix/styles/splitter';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var props = _ref.props;
    return ['p-splitter p-component', 'p-splitter-' + props.layout];
  },
  gutter: 'p-splitter-gutter',
  gutterHandle: 'p-splitter-gutter-handle'
};
var inlineStyles = {
  root: function root(_ref2) {
    var props = _ref2.props;
    return [{
      display: 'flex',
      'flex-wrap': 'nowrap'
    }, props.layout === 'vertical' ? {
      'flex-direction': 'column'
    } : ''];
  }
};
var SplitterStyle = BaseStyle.extend({
  name: 'splitter',
  style: style,
  classes: classes,
  inlineStyles: inlineStyles
});

export { SplitterStyle as default };
//# sourceMappingURL=index.mjs.map
