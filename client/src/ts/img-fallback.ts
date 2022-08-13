import { css, html, LitElement } from "lit";
import { customElement } from "lit/decorators/custom-element.js";
import { property } from "lit/decorators/property.js";

@customElement("img-fallback")
// eslint-disable-next-line @typescript-eslint/no-unused-vars
class ImgFallback extends LitElement {
  @property()
  src?: string;

  @property()
  alt?: string;

  @property()
  ["fallback-src"]?: string;

  @property()
  ["fallback-alt"]?: string;

  @property({ type: Boolean })
  fallback = false;

  get activeSrc(): string | undefined {
    return this.fallback ? this["fallback-src"] : this.src;
  }

  get activeAlt(): string | undefined {
    return (this.fallback ? this["fallback-alt"] : undefined) ?? this.alt;
  }

  private switchToFallback(): void {
    this.fallback = true;
  }

  static get styles() {
    return css`
      :host {
        overflow: hidden;
      }

      img {
        width: 100%;
        height: 100%;
        overflow: hidden;
      }
    `;
  }

  render() {
    return html`<img
      src="${this.activeSrc}"
      alt="${this.activeAlt}"
      @error="${this.switchToFallback}"
    />`;
  }
}
