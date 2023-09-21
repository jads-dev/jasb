import { type CSSResultGroup, html, LitElement, nothing, unsafeCSS } from "lit";
import {
  customElement,
  eventOptions,
  property,
  state,
  query,
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

  _animationMode = "multi"
  _hasEventListener = false

  /**
   * The animation mode of the card, valid values are ("multi", "single")
   */
  @property()
  get animationMode() {
    return this._animationMode
  }

  set animationMode(newValue: string) {
    const oldValue = this._animationMode;
    this._animationMode = newValue;
    this.requestUpdate('animationMode', oldValue); 
    if (this.animationMode != "multi" && this.animationMode != "single") {
      if (this._hasEventListener) {
        window.removeEventListener('mousemove', this.updateMousePosition);
        this._hasEventListener = false 
      }
      this._interpolateToPosition = { x: 0, y: 0 }
    } else {
      if (!this._hasEventListener) {
        window.addEventListener('mousemove', this.updateMousePosition.bind(this));
        this._hasEventListener = true
      }
    }
  }

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

  @state()
  declare private _effectFocus: { x: number; y: number };

  @state()
  declare private _effectDistance: number;
  
  @state()
  private _interpolateToPosition = { x: 0, y: 0 }
  
  @query('#card')
  private _card?: HTMLElement;

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
    this._effectFocus = { x: 0, y: 0 };
    this._effectOpacity = 0;
  }  

  override connectedCallback() {
    super.connectedCallback();
    this.interpolate();
    if (this.animationMode != "multi" && this.animationMode != "single")
      return

    if (!this._hasEventListener) {
      window.addEventListener('mousemove', this.updateMousePosition.bind(this));
      this._hasEventListener = true
    }
  }

  override disconnectedCallback() {
    super.disconnectedCallback();
    if (this.animationMode != "multi" && this.animationMode != "single")
      return
    if (this._hasEventListener) {
      window.removeEventListener('mousemove', this.updateMousePosition);
      this._hasEventListener = false 
    }
  }

  @eventOptions({ passive: true })
  updateMousePosition(event: MouseEvent) {
    if (this._card !== undefined && this._card !== null) {
      const { left, top, width, height } = this._card.getBoundingClientRect();

      let x = ((event.clientX - (left + width / 2)) / (width / 2)) * 100;
      let y = ((event.clientY - (top + height / 2)) / (height / 2)) * 100;
    
      if (this.animationMode == "multi") {
        x = clamp(x, -150, 150)
        y = clamp(y, -150, 150)
        
        if (Math.abs(x) == 150)
          y = 0
        if (Math.abs(y) == 150)
          x = 0
        
        x -= (x - 100 * clamp(x / 100, -0.75, 0.75)) * 2
        y -= (y - 100 * clamp(y / 100, -0.75, 0.75)) * 2
      } else if (this.animationMode == "single") {
        if (Math.abs(x) > 100 || Math.abs(y) > 100) {
          this._interpolateToPosition = {x: 0, y: 0}
          return
        }
      }
      
      this._interpolateToPosition = {x: x, y: y};
    }
  }

  interpolate() {
    if (this._effectFocus.x != this._interpolateToPosition.x) {
      var dx = this._interpolateToPosition.x - this._effectFocus.x
      this._effectFocus.x += dx * 0.1
    }
    
    if (this._effectFocus.y != this._interpolateToPosition.y) {
      var dy = this._interpolateToPosition.y - this._effectFocus.y
      this._effectFocus.y += dy * 0.1
    }
    
    if (this._card !== undefined && this._card !== null) {
      const { width, height } = this._card.getBoundingClientRect();
      this._effectDistance = (this._effectFocus.x ** 2 + this._effectFocus.y ** 2) / ((width / 2) ** 2 + (height / 2) ** 2) * 2
    }

    this.requestUpdate(); 
    requestAnimationFrame(() => this.interpolate());
  }

  override render() {
    const customProperties = {
      "--effect-focus-x": `${this._effectFocus.x}%`,
      "--effect-focus-y": `${this._effectFocus.y}%`,
      "--effect-focus-from-center": `${this._effectDistance}`,
      "--rotate-x": `${-this._effectFocus.x / 10}deg`,
      "--rotate-y": `${this._effectFocus.y / 10}deg`,
    };
    return html`
      <div 
        id="card"
        style="${styleMap(customProperties)}">
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
