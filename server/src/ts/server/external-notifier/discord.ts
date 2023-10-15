import * as Discord from "discord.js";

import { Feed } from "../../internal/feed.js";
import { Users } from "../../internal/users.js";
import { Expect } from "../../util/expect.js";
import { Iterables } from "../../util/iterables.js";
import type { Config } from "../config.js";
import type { Notifier } from "./notifiers.js";

interface DiscordMessage {
  title: string;
  url: string;
  description: string;
  mentionedUsers?: string[];
}

const spoilerIf = (needsMasking: boolean) =>
  needsMasking ? Discord.spoiler : (v: string) => v;

const joinAnd = (
  segments: Iterable<string>,
  joiner = ", ",
  and = ", and ",
): Iterable<string> => {
  const segmentList = [...segments];
  if (segmentList.length < 2) {
    return segmentList;
  } else {
    const empty = Array(segmentList.length - 2) as undefined[];
    const joints = [...empty].map(() => joiner);
    joints.push(and);
    return Iterables.interleave(segmentList, joints);
  }
};

const describeUser = (user: Users.Summary) => {
  const name =
    user.discriminator === null
      ? user.name
      : `${user.name}#${user.discriminator}`;
  return `${name} (${Discord.userMention(user.discord_id)})`;
};

export class DiscordNotifier implements Notifier {
  readonly #generalConfig: Config.Server;
  readonly #config: Config.DiscordNotifier;
  readonly #client: Discord.Client;
  readonly #channel: Discord.TextChannel;

  private constructor(
    generalConfig: Config.Server,
    config: Config.DiscordNotifier,
    client: Discord.Client,
    channel: Discord.TextChannel,
  ) {
    this.#generalConfig = generalConfig;
    this.#config = config;
    this.#client = client;
    this.#channel = channel;
  }

  static async create(
    generalConfig: Config.Server,
    config: Config.DiscordNotifier,
  ): Promise<Notifier> {
    const client = new Discord.Client({
      intents: new Discord.IntentsBitField(),
    });
    await client.login(config.token.value);
    const channelId = config.channel;
    const channel = await client.channels.fetch(channelId);
    if (channel instanceof Discord.TextChannel) {
      return new this(generalConfig, config, client, channel);
    } else {
      throw new Error(
        `The given channel (${channelId}) is not a valid text channel.`,
      );
    }
  }

  #render(origin: string, event: Feed.Event): DiscordMessage {
    const type = event.type;
    switch (type) {
      case "NewBet": {
        const mask = spoilerIf(event.spoiler);
        return {
          title: "New Bet",
          description: `New bet available on “${event.game.name}”: “${mask(
            event.bet.name,
          )}”.`,
          url: `${origin}/games/${event.game.slug}/${event.bet.slug}`,
        };
      }

      case "NotableStake": {
        const mask = spoilerIf(event.spoiler);
        return {
          title: "Big Bet",
          description: `Big bet of ${event.stake} with the message “${mask(
            event.message,
          )}” on “${mask(event.option.name)}” in the bet “${mask(
            event.bet.name,
          )}” for the game “${event.game.name}”.`,
          url: `${origin}/games/${event.game.slug}/${event.bet.slug}`,
        };
      }

      case "BetComplete": {
        const mask = spoilerIf(event.spoiler);
        const otherWinnerCount =
          event.winningStakes - event.highlighted.winners.length;
        const others =
          otherWinnerCount > 0
            ? ` They and ${otherWinnerCount} others share a total of ${event.totalReturn} in winnings.`
            : "";
        const winningUsers = joinAnd(
          event.highlighted.winners.map(describeUser),
        );
        const highlighted =
          event.winningStakes > 0
            ? `${Iterables.join(winningUsers)} ${
                event.highlighted.winners.length > 1 ? "each won" : "won"
              } ${event.highlighted.amount}!${others}`
            : `No one bet on ${
                event.winners.length > 1 ? "those options" : "that option"
              }!`;
        const winningOptions = joinAnd(
          event.winners.map((option) => `“${mask(option.name)}”`),
        );
        return {
          title: "Bet Complete",
          description: `The bet “${mask(event.bet.name)}” for the game “${
            event.game.name
          }” has been resolved—${Iterables.join(
            winningOptions,
          )} won!\n\n${highlighted}`,
          url: `${origin}/games/${event.game.slug}/${event.bet.slug}`,
          mentionedUsers: event.highlighted.winners.map(
            (user) => user.discord_id,
          ),
        };
      }

      default:
        return Expect.exhaustive("feed event type")(type);
    }
  }

  async notify(getEvent: () => Promise<Feed.Event>): Promise<void> {
    const event = await getEvent();
    const { title, url, description, mentionedUsers } = this.#render(
      this.#generalConfig.clientOrigin,
      event,
    );
    await this.#channel.send({
      embeds: [
        {
          title,
          description,
          url,
          thumbnail: {
            url: `${this.#generalConfig.clientOrigin}/assets/monocoin.png`,
          },
        },
      ],
      tts: false,
      allowedMentions:
        mentionedUsers !== undefined && mentionedUsers.length > 0
          ? {
              parse: ["users"],
              users: mentionedUsers,
            }
          : { parse: [] },
    });
  }
}
