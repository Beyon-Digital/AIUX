# Semantic actions

Renderers never mutate the session — every interactive control emits an
`AIUXAction` (`{id, payload}`) that **your host routes**. This is the full
vocabulary a renderer can emit, and what to implement for each.

## Composer

| Action | Emitted when | Payload | Host should |
| --- | --- | --- | --- |
| `aiux.composer.send` | Native send (also `submit` on web) | `{text}` | Prompt the agent → start a run |
| `aiux.composer.submit` | Web composer send | `{text}` | Same as send |
| `aiux.composer.cancel` | Cancel button while a run is active | — | Emit `run.cancelled`, stop the stream |
| `aiux.composer.attach` | `+` attach button | — | Open your picker; add attachments to context |
| `aiux.composer.tools` | Tools toggle | — | Toggle your tools UI |
| `aiux.composer.dictate` | Mic button | — | Toggle dictation |
| `aiux.composer.voice` | Voice-mode affordance | — | Enter voice mode |
| `aiux.composer.docs` | Example's custom docs tool | — | Custom — yours |

## Approvals

| Action | Emitted when | Payload | Host should |
| --- | --- | --- | --- |
| `aiux.approval.approve` | Approve a pending tool/action gate | `{approvalId}` | Emit `approval.resolved {resolution:"approved"}` + continue the run |
| `aiux.approval.reject` | Reject | `{approvalId}` | Emit `approval.resolved {resolution:"rejected"}` |
| `aiux.approval.resolve` | Custom resolution path | `{approvalId, resolution?}` | Emit `approval.resolved` |

## Errors & entities

| Action | Emitted when | Payload | Host should |
| --- | --- | --- | --- |
| `aiux.error.retry` | Retry affordance on a failed run/message | `{runId?, messageId?}` | Re-run: new `run.started`, replay |
| `aiux.artifact.open` | Artifact preview tapped | `{artifactId}` | Open/navigate to the artifact |
| `aiux.citation.open` | Citation chip tapped | `{citationId?, url?}` | Open the source |
| `aiux.attachment.open` | Attachment tapped | `{attachmentId?, url?}` | Preview/open |
| `aiux.image.open` | Inline image tapped | `{url}` | Preview/open |

## Context bar

| Action | Emitted when | Payload | Host should |
| --- | --- | --- | --- |
| `aiux.context.add` | `+` in context bar | — | Add entity to next `run.started` context |
| `aiux.context.open` | Entity chip tapped | `{entityId}` | Navigate to the entity |
| `aiux.context.remove` | Remove affordance | `{entityId}` | Drop it from context |

## Surfaces

Field changes inside a generated surface:

| Action | Payload |
| --- | --- |
| `aiux.surface.input` / `.input.change` | `{surfaceId, nodeId, value}` |
| `aiux.surface.select.change` | `{surfaceId, nodeId, value}` |
| `aiux.surface.checkbox.change` | `{surfaceId, nodeId, value}` |
| `aiux.surface.radio.change` | `{surfaceId, nodeId, value}` |
| `aiux.field.change` | `{fieldId?, value}` — legacy field-level |

`form` submit buttons emit the button's `action` with collected `fields` in
the payload — often a host-defined id (that's the point of forms: the agent
authors the action name; see [surfaces](surfaces.md#forms)).

`aiux.unresolved` — fallback emitted when a surface `action` references a
node that can't be resolved; treat as a no-op worth logging.

## Routing pattern

```ts
onAction={(action) => {
  switch (action.id) {
    case "aiux.composer.send":     // native
    case "aiux.composer.submit":   // web
      return controller.sendMessage(action.payload?.text);
    case "aiux.composer.cancel":   return controller.cancelRun();
    case "aiux.approval.approve":  return controller.resolveApproval(action.payload?.approvalId, "approved");
    case "aiux.approval.reject":   return controller.resolveApproval(action.payload?.approvalId, "rejected");
    case "aiux.error.retry":       return controller.retryRun();
    case "aiux.composer.attach":   return openPicker();
    case "aiux.composer.tools":    return toggleTools();
    case "aiux.composer.dictate":  return toggleDictation();
    case "aiux.surface.input.change":
    case "aiux.surface.select.change":
    case "aiux.surface.checkbox.change":
    case "aiux.surface.radio.change":
      return controller.updateField(action.payload);
    default:                       return controller.customAction(action);
  }
}}
```

The example's full router:
[`examples/expo/src/DemoController.ts`](../../examples/expo/src/DemoController.ts)
(691 lines — covers every id above plus the scripted mock flow). Compose
constant names: [`AIUXActions`](../api/compose.md#actions--aiuxactions-constants).

## Rules

- **Payload access**: JS payloads are plain objects; Compose payloads are
  `JsonObject` (`action.payload["text"]?.jsonPrimitive?.content`);
  Swift `AIUXAction.payload` is `AIUXJSONValue`.
- **Your action ids are yours**: buttons/forms inside surfaces and custom
  composer tools emit whatever `id` you authored — route them to your own
  features (navigation, app actions, follow-up prompts).
- **Never dispatch an event just because a control was tapped** — actions
  describe *intent*; the core only learns what your host decides to emit.
