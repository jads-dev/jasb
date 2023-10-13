import {
  type CSSResultGroup,
  html,
  LitElement,
  type PropertyValues,
  unsafeCSS,
} from "lit";
import {
  customElement,
  eventOptions,
  property,
  query,
  state,
} from "lit/decorators.js";
import { styleMap } from "lit/directives/style-map.js";
import { when } from "lit/directives/when.js";

import { default as styles } from "../scss/gacha-card.scss?inline";
import { clamp, roughlyEquals, spaceSeparatedList } from "./util.mjs";

type PercentCoordinates = readonly [x: number, y: number];

const smallChange = 2 ** -6;
const percentCoordinatesHaveChanged = (
  newValue: PercentCoordinates,
  oldValue?: PercentCoordinates,
) => {
  if (oldValue === undefined) {
    return true;
  } else {
    const [newX, newY] = newValue;
    const [oldX, oldY] = oldValue;
    return (
      !roughlyEquals(newX, oldX, smallChange) ||
      !roughlyEquals(newY, oldY, smallChange)
    );
  }
};

@customElement("gacha-card")
export class GachaCard extends LitElement {
  static override styles: CSSResultGroup = [unsafeCSS(styles)];
  /**
   * Percentage of the size of the card from the centre to start interactions
   * within (50 therefore means within the card).
   */
  static interactionBufferZone = 75;
  /**
   * The speed in percent per millisecond.
   */
  static interpolateSpeed = 10 / 1000;

  /**
   * The serial number of the card.
   */
  @property({ attribute: "serial-number", type: Number })
  declare serialNumber: number | undefined;

  /**
   * The issue number of the card.
   */
  @property({ attribute: "issue-number", type: Number })
  declare issueNumber: number | undefined;

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
   * If this._card is a sample of a card type, rather than an actual card
   * which exists.
   */
  @property({ type: Boolean })
  declare sample: boolean;

  @state({ hasChanged: percentCoordinatesHaveChanged })
  declare _effectFocus: PercentCoordinates;

  @state({ hasChanged: percentCoordinatesHaveChanged })
  declare _effectFocusTarget: PercentCoordinates;

  @query("#card")
  private declare _card: HTMLElement | null;

  #interacting = false;
  #effectDistanceFromCenter = 0;
  #eventListener: ((event: MouseEvent) => void) | undefined = undefined;
  #interpolationRequested = false;

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
    this._effectFocus = [0, 0];
  }

  override async connectedCallback() {
    super.connectedCallback();
    await this.updateComplete;
    this.#handleEventListener(this.interactive);
  }

  override disconnectedCallback() {
    super.disconnectedCallback();
    this.#handleEventListener(false);
  }

  #handleEventListener(interactive: boolean) {
    if (interactive) {
      const card = this._card;
      if (card !== null && this.#eventListener === undefined) {
        this.#eventListener = (event: MouseEvent) => {
          this.updateMousePosition(card, event);
        };
        window.addEventListener("pointermove", this.#eventListener);
      }
    } else {
      if (this.#eventListener !== undefined) {
        window.removeEventListener("pointermove", this.#eventListener);
        this.#eventListener = undefined;
      }
    }
  }

  @eventOptions({ passive: true })
  updateMousePosition(card: HTMLElement, event: MouseEvent) {
    const bufferZone = GachaCard.interactionBufferZone;
    const { left, top, width, height } = card.getBoundingClientRect();
    if (width !== 0 && height !== 0) {
      const x = ((event.clientX - left) / width) * 100 - 50;
      const y = ((event.clientY - top) / height) * 100 - 50;
      if (Math.abs(x) <= bufferZone && Math.abs(y) <= bufferZone) {
        this.#interacting = true;
        this._effectFocusTarget = [clamp(x, -50, 50), clamp(y, -50, 50)];
      } else {
        this.#interacting = false;
        this._effectFocusTarget = [0, 0];
      }
    }
  }

  #interpolateNextFrameIfNeeded(lastTime?: number) {
    if (!this.#interpolationRequested) {
      const [focusX, focusY] = this._effectFocus;
      const [targetX, targetY] = this._effectFocusTarget;
      if (!roughlyEquals(focusX, targetX) || !roughlyEquals(focusY, targetY)) {
        requestAnimationFrame((time) => {
          this.interpolate(time, lastTime);
        });
        this.#interpolationRequested = true;
      } else {
        this._effectFocus = [targetX, targetY];
      }
    }
  }

  interpolate(time: number, lastTime?: number) {
    this.#interpolationRequested = false;
    if (lastTime !== undefined) {
      const millisSinceLastFrame = time - lastTime;
      const rateOfChange = GachaCard.interpolateSpeed * millisSinceLastFrame;

      const [focusX, focusY] = this._effectFocus;
      const [targetX, targetY] = this._effectFocusTarget;

      const updated = (current: number, want: number, rateOfChange: number) => {
        const difference = (want - current) * rateOfChange;
        const updated = current + difference;
        return difference > 0
          ? Math.min(want, updated)
          : Math.max(want, updated);
      };

      this._effectFocus = [
        updated(focusX, targetX, rateOfChange),
        updated(focusY, targetY, rateOfChange),
      ];
    }

    this.#interpolateNextFrameIfNeeded(time);
  }

  override willUpdate(changedProperties: PropertyValues<this>): void {
    if (changedProperties.has("interactive")) {
      this.#handleEventListener(this.interactive);
    }
    if (changedProperties.has("_effectFocus")) {
      const [x, y] = this._effectFocus;
      this.#effectDistanceFromCenter = (x ** 2 + y ** 2) / 5000;
    }
    if (changedProperties.has("_effectFocusTarget")) {
      this.#interpolateNextFrameIfNeeded();
    }
  }

  override render() {
    const [focusX, focusY] = this._effectFocus;
    const customProperties = {
      "--effect-opacity": `${
        this.#interacting ? 1 : this.#effectDistanceFromCenter
      }`,
      "--effect-focus-x": `${focusX + 50}%`,
      "--effect-focus-y": `${focusY + 50}%`,
      "--effect-focus-from-center": `${this.#effectDistanceFromCenter}`,
      "--rotate-x": `${-focusX / 4}deg`,
      "--rotate-y": `${focusY / 4}deg`,
    };
    return html`
      <div id="card" style="${styleMap(customProperties)}">
        <div class="pivot">
          <div class="side reverse">
            <div class="content"></div>
          </div>
          <div class="side face">
            <div class="border"></div>
            <div class="background"></div>
            <div class="effect shine"></div>
            <div class="content">
              ${when(
                this.serialNumber !== undefined,
                () =>
                  html`<span class="serial-number">${this.serialNumber?.toString()?.padStart(10, "0")}</span>`,
              )}
              ${when(
                this.issueNumber !== undefined,
                () =>
                  html`<span class="issue-number">${this.issueNumber?.toString()?.padStart(5, "0")}</span>`,
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
