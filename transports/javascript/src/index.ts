export { createEventFactory } from "./factory";
export type { EventFactory, EventFactoryOptions } from "./factory";
export { streamToBatches } from "./batcher";
export type {
  StreamToBatchesOptions,
  StreamToBatchesResult,
} from "./batcher";
export { createWireNormalizer } from "./normalize";
export type {
  NormalizeTarget,
  WireNormalizer,
  WireNormalizerOptions,
} from "./normalize";
export {
  TERMINAL_EVENT_TYPES,
  isTerminalEvent,
} from "./types";
export type {
  AdapterIssue,
  EventBatchSink,
  EventBatchSource,
} from "./types";
