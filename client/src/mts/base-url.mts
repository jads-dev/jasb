export interface BaseUrl {
  protocol: string;
  host: string;
  path: string;
}

const baseFromHtml = (baseElement: HTMLBaseElement): BaseUrl => {
  const { protocol, host, pathname } = new URL(baseElement.href);
  return {
    protocol,
    host,
    path: pathname.endsWith("/") ? pathname.slice(0, -1) : pathname,
  };
};

// Fallback - we should always have a base element so this should never get
// hit. Note that we can't work out the base path from this.
const baseFromLocation = (): BaseUrl => {
  const url = window.location;
  return {
    protocol: url.protocol,
    host: url.host,
    path: "",
  };
};

export const discover = (): BaseUrl => {
  const baseElement = document.querySelector("base");
  return baseElement !== null ? baseFromHtml(baseElement) : baseFromLocation();
};
