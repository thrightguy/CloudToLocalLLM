import BaseStyle from '@primevue/core/base/style';

var inlineStyles = {
  root: {
    position: 'relative'
  }
};
var classes = {
  root: 'p-chart'
};
var ChartStyle = BaseStyle.extend({
  name: 'chart',
  classes: classes,
  inlineStyles: inlineStyles
});

export { ChartStyle as default };
//# sourceMappingURL=index.mjs.map
