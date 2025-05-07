// src/eventbus/index.ts
function EventBus() {
  const allHandlers = /* @__PURE__ */ new Map();
  return {
    on(type, handler) {
      let handlers = allHandlers.get(type);
      if (!handlers) handlers = [handler];
      else handlers.push(handler);
      allHandlers.set(type, handlers);
      return this;
    },
    off(type, handler) {
      const handlers = allHandlers.get(type);
      if (handlers) {
        handlers.splice(handlers.indexOf(handler) >>> 0, 1);
      }
      return this;
    },
    emit(type, evt) {
      const handlers = allHandlers.get(type);
      if (handlers) {
        handlers.forEach((handler) => {
          handler(evt);
        });
      }
    },
    clear() {
      allHandlers.clear();
    }
  };
}
export {
  EventBus
};
//# sourceMappingURL=index.mjs.map