// 0.9.15 Addendum A (Vamsi 03:36 CST): a job instance id as a link to the real IDMC portal job
// page, opened in a new tab. The URL comes ONLY from the backend's typed portal_url field
// (app/common/portal.py); nothing is concatenated here. No URL -> the id as plain code.
export function PortalLink({ id, url, slug }: { id: string; url: string | null | undefined; slug: string }): React.JSX.Element {
  if (url === null || url === undefined || url === "") return <code>{id}</code>;
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`Open job ${id} in IDMC portal`}
      data-testid={`portal-link-${slug}-${id}`}
    >
      <code>{id}</code>
    </a>
  );
}

/** 0.9.15 Addendum B (Vamsi 03:44 CST): "Go to IDMC" under a taskflow run id. URL from the
 * backend's typed portal_url only; nothing rendered when it is missing. */
export function GoToIdmc({ runId, url, slug }: { runId: string; url: string | null | undefined; slug: string }): React.JSX.Element | null {
  if (url === null || url === undefined || url === "") return null;
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`Open taskflow run ${runId} in IDMC portal`}
      data-testid={`go-to-idmc-${slug}-${runId}`}
      onClick={(e) => e.stopPropagation()}
    >
      Go to IDMC
    </a>
  );
}

/** 0.9.16 (Vamsi 03:57 CST, Design notebook page ONLY): a design asset's name as a link to its
 * IDMC portal page, plus a "Go to IDMC" variant. URL from the backend's typed portal_url only;
 * no URL -> plain name / nothing. */
export function DesignAssetLink({
  name,
  typeLabel,
  url,
  slug,
  goTo = false,
}: {
  name: string;
  typeLabel: string;
  url: string | null | undefined;
  slug: string;
  goTo?: boolean;
}): React.JSX.Element | null {
  if (url === null || url === undefined || url === "") return goTo ? null : <>{name}</>;
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`Open ${typeLabel} ${name} in IDMC portal`}
      data-testid={`${goTo ? "design-go-to-idmc" : "design-portal-link"}-${slug}`}
      onClick={(e) => e.stopPropagation()}
    >
      {goTo ? "Go to IDMC" : name}
    </a>
  );
}
