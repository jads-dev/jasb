import { type CSSResultGroup, html, LitElement, nothing, unsafeCSS } from "lit";
import {
  customElement,
  eventOptions,
  property,
  state,
} from "lit/decorators.js";
import { styleMap } from "lit/directives/style-map.js";
import { when } from "lit/directives/when.js";

import { clamp, rescale, spaceSeparatedList } from "./util.mjs";
import { default as styles } from "../scss/gacha-card.scss?inline";

@customElement("gacha-card")
export class GachaCard extends LitElement {
  static override styles: CSSResultGroup = [unsafeCSS(styles)];

  /**
   * The serial number of the card.
   */
  @property({ attribute: "serial-number" })
  declare serialNumber: string | undefined;

  /**
   * The name of the card.
   */
  @property()
  declare name: string;

  /**
   * The description on the card.
   */
  @property()
  declare description: string;

  /**
   * The image on the card.
   */
  @property()
  declare image: string | undefined;

  /**
   * The rarity of the card.
   */
  @property()
  declare rarity: string;

  /**
   * The banner the card is in.
   */
  @property()
  declare banner: string | undefined;

  /**
   * The layout of the card.
   */
  @property()
  declare layout: string;

  // /**
  //  * The variant of the card.
  //  */
  // @property()
  // declare variant;

  /**
   * Qualities the card has.
   */
  @property({ converter: spaceSeparatedList })
  declare qualities: string[];

  /**
   * If the card can be interacted with, giving it some movement and
   * lighting effects from the mouse cursor, making the card feel more
   * like a physical object.
   */
  @property({ type: Boolean })
  declare interactive: boolean;

  /**
   * If this card is a sample of a card type, rather than an actual card
   * which exists.
   */
  @property({ type: Boolean })
  declare sample: boolean;

  @state()
  private declare _effectFocus: { x: number; y: number };

  @state()
  private declare _effectOpacity: number;

  #active = false;
  #previousInactiveStep: number | undefined;
  #setNotActive: ReturnType<typeof setTimeout> | undefined;

  constructor() {
    super();
    this.serialNumber = undefined;
    this.name = "";
    this.description = "";
    this.image = undefined;
    this.rarity = "m";
    this.banner = undefined;
    this.layout = "normal";
    this.qualities = [];
    this.interactive = false;
    this.sample = false;
    this._effectFocus = { x: 50, y: 50 };
    this._effectOpacity = 0;
  }

  @eventOptions({ passive: true })
  updateMousePosition(event: PointerEvent) {
    this.#active = true;
    this._effectOpacity = 1;
    const target = event.target;
    if (target !== null && target instanceof HTMLElement) {
      const { left, top, width, height } = target.getBoundingClientRect();
      this._effectFocus = {
        x: clamp((100 / width) * (event.clientX - left), 0, 100),
        y: clamp((100 / height) * (event.clientY - top), 0, 100),
      };
      clearTimeout(this.#setNotActive);
      this.#setNotActive = setTimeout(() => {
        this.#active = false;
        requestAnimationFrame((time) => {
          this.#resetToInactive(time);
        });
      }, 1000);
    }
  }

  #resetToInactive(time: number) {
    if (!this.#active) {
      if (this.#previousInactiveStep !== undefined) {
        const step = time - this.#previousInactiveStep;
        const opacityDownRate = 0.005 * step;
        const moveRate = 0.05 * step;
        const towards50 = (value: number) =>
          clamp(value + (value < 50 ? moveRate : -moveRate), 0, 100);
        this._effectOpacity = clamp(
          this._effectOpacity - opacityDownRate,
          0,
          1,
        );
        this._effectFocus = {
          x: towards50(this._effectFocus.x),
          y: towards50(this._effectFocus.y),
        };
      }
      this.#previousInactiveStep = time;
      if (
        this._effectOpacity > 0 ||
        this._effectFocus.x > 51 ||
        this._effectFocus.x < 49 ||
        this._effectFocus.y > 51 ||
        this._effectFocus.y < 49
      ) {
        requestAnimationFrame((time) => {
          this.#resetToInactive(time);
        });
      } else {
        this._effectOpacity = 0;
        this._effectFocus = { x: 50, y: 50 };
        this.#previousInactiveStep = undefined;
      }
    } else {
      this.#previousInactiveStep = undefined;
    }
  }

  override render() {
    const distanceFromCenter = clamp(
      Math.sqrt(
        (this._effectFocus.x - 50) ** 2 + (this._effectFocus.y - 50) ** 2,
      ) / 50,
      0,
      1,
    );
    const customProperties = {
      "--effect-focus-x": `${this._effectFocus.x}%`,
      "--effect-focus-y": `${this._effectFocus.y}%`,
      "--effect-focus-from-center": `${distanceFromCenter}`,
      "--rotate-x": `${rescale(100 - this._effectFocus.x, 0, 100, -10, 10)}deg`,
      "--rotate-y": `${rescale(this._effectFocus.y, 0, 100, -10, 10)}deg`,
      "--effect-opacity": this._effectOpacity,
    };
    return html`
      <div class="card" style="${styleMap(customProperties)}">
        <div
          class="rotator"
          @pointermove="${this.interactive
            ? (event: PointerEvent) => {
                this.updateMousePosition(event);
              }
            : nothing}"
        >
          <div class="side reverse">
            <div class="content"></div>
          </div>
          <div class="side face">
            <div class="border"></div>
            <div class="background"></div>
            <div class="effect shine"></div>
            <div class="content">
              ${when(
                this.serialNumber,
                () =>
                  html`<span class="serial-number">${this.serialNumber}</span>`,
              )}
              <div class="image">
                <img src="${this.image}" alt="${this.name}" />
              </div>
              <div class="details">
                <div class="rarity ${this.rarity}"></div>
                <span class="name" data-name="${this.name}">${this.name}</span>
                <span class="description">${this.description}</span>
                ${when(
                  this.qualities,
                  () =>
                    html`<ul class="qualities">
                      ${this.qualities.map(
                        (quality) => html`<li class="quality ${quality}"></li>`,
                      )}
                    </ul>`,
                )}
              </div>
            </div>
            <div class="effect glare"></div>
          </div>
        </div>
      </div>
    `;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    "gacha-card": GachaCard;
  }
}
