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
