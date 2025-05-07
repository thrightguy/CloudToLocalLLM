type Handler = (evt: unknown) => void;
interface EventBusOptions {
    on(type: string, handler: Handler): void;
    off(type: string, handler: Handler): void;
    emit(type: string, evt?: unknown): void;
    clear(): void;
}
declare function EventBus(): EventBusOptions;

export { EventBus, type EventBusOptions, type Handler };
