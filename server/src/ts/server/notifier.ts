import { default as Discord, TextChannel } from "discord.js";
import { default as Winston } from "winston";

import { Feed } from "../public";
import { Config } from "./config";

export interface Notifier {
  notify: (event: Feed.Event) => Promise<void>;
}

export class NullNotifier implements Notifier {
  async notify(_: Feed.Event): Promise<void> {
    // Do Nothing.
  }
}

export class DiscordNotifier implements Notifier {
  generalConfig: Config.Server;
  config: Config.DiscordNotifier;
  client: Discord.Client;

  private constructor(
    generalConfig: Config.Server,
    config: Config.DiscordNotifier
  ) {
    this.generalConfig = generalConfig;
    this.config = config;
    const intents = new Discord.Intents();
    this.client = new Discord.Client({ intents });
  }

  static async create(
    logger: Winston.Logger,
    generalConfig: Config.Server,
    config: Config.DiscordNotifier
  ): Promise<Notifier> {
    const instance = new this(generalConfig, config);
    try {
      await instance.login();
    } catch (error) {
      logger.error(
        "Failure while setting up notifier, reverting to null notifier.",
        { exception: error }
      );
      return new NullNotifier();
    }
    return instance;
  }

  async login(): Promise<void> {
    await this.client.login(this.config.token.value);
  }

  async notify(event: Feed.Event): Promise<void> {
    const { message, mentionedUsers } = DiscordNotifier.messageFromEvent(event);
    const channel = (await this.client.channels.fetch(
      this.config.channel
    )) as TextChannel;
    await channel.send({
      embeds: [
        {
          title: `Stream Bets—“${DiscordNotifier.wrapSpoiler(
            event.bet.name,
            event.spoiler
          )}” bet for ${event.game.name}`,
          description: message,
          url: `${this.generalConfig.clientOrigin}/games/${event.game.id}/${event.bet.id}`,
          thumbnail: {
            url: "https://jasb.900000000.xyz/assets/images/favicon-48x48.png",
          },
        },
      ],
      tts: false,
      allowedMentions:
        mentionedUsers === undefined
          ? { parse: [] }
          : {
              parse: ["users"],
              users: mentionedUsers,
            },
    });
  }

  private static wrapSpoiler(text: string, isSpoiler: boolean): string {
    return isSpoiler ? `||${text}||` : `${text}`;
  }

  private static messageFromEvent(event: Feed.Event): {
    message: string;
    mentionedUsers?: string[];
  } {
    switch (event.type) {
      case "NewBet":
        return {
          message: `New bet: (${event.game.name}) “${this.wrapSpoiler(
            event.bet.name,
            event.spoiler
          )}”.`,
        };

      case "BetComplete": {
        const otherWinnerCount =
          event.winningBets - event.highlighted.winners.length;
        const others =
          otherWinnerCount > 0
            ? ` They and ${otherWinnerCount} others share a total of ${event.totalReturn} in winnings.`
            : "";
        const winners = event.highlighted.winners
          .map((w) => `<@${w.id}>`)
          .join(", ");
        const winInfo =
          event.winningBets > 0
            ? `${winners} ${
                event.highlighted.winners.length > 1 ? "each won" : "won"
              } ${event.highlighted.amount}!${others}`
            : "No one bet on that option!";
        const winningOptions = event.winners
          .map((w) => `“${w.name}”`)
          .join(", ");
        return {
          message: `The bet “${this.wrapSpoiler(
            event.bet.name,
            event.spoiler
          )}” for the game ${
            event.game.name
          } has been resolved. ${this.wrapSpoiler(
            winningOptions,
            event.spoiler
          )} won!\n\n${winInfo}`,
        };
      }

      case "NotableStake":
        return {
          message: `Big bet of ${event.stake} on “${this.wrapSpoiler(
            event.option.name,
            event.spoiler
          )}” in the bet “${this.wrapSpoiler(
            event.bet.name,
            event.spoiler
          )}” for the game ${event.game.name}.\n\n<@${
            event.user.id
          }>: “${this.wrapSpoiler(event.message, event.spoiler)}”.`,
          mentionedUsers: [event.user.id],
        };

      default:
        return Feed.unknownEvent(event);
    }
  }
}
