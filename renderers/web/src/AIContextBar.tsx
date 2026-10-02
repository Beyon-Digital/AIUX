import { AiuxIcon } from "./icons.jsx";
import type { ContextEntity } from "./types.js";

const KIND_ICON: Record<string, string> = {
  file: "file",
  url: "link",
  link: "link",
  image: "image",
  issue: "warning",
};

/** Context-entity chips injected into the session (file, issue, URL, …). */
export function AIContextBar({
  entities,
}: {
  entities: readonly ContextEntity[];
}) {
  if (entities.length === 0) return null;
  return (
    <div className="aiux-context" role="complementary" aria-label="Context">
      <ul className="aiux-context__list">
        {entities.map((entity) => {
          const chip = (
            <>
              <AiuxIcon name={KIND_ICON[entity.kind] ?? "info"} size="sm" />
              <span className="aiux-context__label">{entity.label}</span>
              <span className="aiux-context__kind">{entity.kind}</span>
            </>
          );
          return (
            <li key={entity.id} className="aiux-context__item">
              {entity.uri ? (
                <a
                  className="aiux-context__chip"
                  href={entity.uri}
                  title={entity.description ?? entity.label}
                >
                  {chip}
                </a>
              ) : (
                <span
                  className="aiux-context__chip"
                  title={entity.description ?? entity.label}
                >
                  {chip}
                </span>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
