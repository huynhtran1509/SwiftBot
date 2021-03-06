// The MIT License (MIT)
// Copyright (c) 2017 Erik Little

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without
// limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
// Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
// BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

import Foundation
import Shared
import SwiftDiscord

enum VoiceChannelCheckResult {
    case fine(DiscordGuildChannel)
    case notFound
    case permissionFail
}

extension Shard : CommandHandler {
    func handleAsk(with arguments: [String], message: DiscordMessage) {
        let randomNum: Int

        #if os(macOS)
        randomNum = Int(arc4random_uniform(2))
        #else
        randomNum = Int(random()) % 2
        #endif

        message.channel?.send(DiscordMessage(content: "```\(arguments.joined(separator: " ")): " +
                "\(["Yes", "No"][randomNum])```"))
    }

    func handleDubs(with arguments: [String], message: DiscordMessage) {
        let randomNum: Int

        #if os(macOS)
        randomNum = Int(arc4random_uniform(1000000))
        #else
        randomNum = Int(random()) % 1000000
        #endif

        message.channel?.send(DiscordMessage(content: "```\(randomNum)```"))
    }


    func handleBrutal(with arguments: [String], message: DiscordMessage) {
        brutalizeImage(options: arguments, channel: message.channel!)
    }

    func handleCommand(_ command: String, with arguments: [String], message: DiscordMessage) {
        print("got command \(command)")

        if let guild = message.channel?.guild, ignoreGuilds.contains(guild.id),
                !userOverrides.contains(message.author.id) {
            print("Ignoring this guild")

            return
        }

        guard let command = Command(rawValue: command.lowercased()) else { return }

        switch command {
        case .ask where arguments.count > 0:
            handleAsk(with: arguments, message: message)
        case .roles:
            handleMyRoles(with: arguments, message: message)
        case .dubs:
            handleDubs(with: arguments, message: message)
        case .join where arguments.count > 0:
            handleJoin(with: arguments, message: message)
        case .leave where arguments.count > 0:
            handleLeave(with: arguments, message: message)
        case .is:
            handleIs(with: arguments, message: message)
        case .youtube where arguments.count == 1:
            handleYoutube(with: arguments, message: message)
        case .fortune:
            handleFortune(with: arguments, message: message)
        case .skip:
            handleSkip(with: arguments, message: message)
        case .brutal where arguments.count > 0:
            handleBrutal(with: arguments, message: message)
        case .talk where arguments.count > 0:
            handleTalk(with: arguments, message: message)
        case .topic where arguments.count > 0:
            handleTopic(with: arguments, message: message)
        case .stats:
            handleStats(with: arguments, message: message)
        case .weather where arguments.count > 0:
            handleWeather(with: arguments, message: message)
        case .wolfram where arguments.count > 0:
            handleWolfram(with: arguments, message: message)
        case .forecast where arguments.count > 0:
            handleForecast(with: arguments, message: message)
        default:
            print("Bad command \(command)")
        }
    }

    func handleFortune(with arguments: [String], message: DiscordMessage) {
        message.channel?.send(DiscordMessage(content: getFortune()))
    }

    func handleIs(with arguments: [String], message: DiscordMessage) {
        guard let guild = message.channel?.guild else {
            message.channel?.send("Is this a guild channel m8?")

            return
        }

        // Avoid evaluating every member.
        let members = guild.members.lazy.map({ $0.value })
        #if os(macOS)
        let randomNum = Int(arc4random_uniform(UInt32(guild.members.count)))
        #else
        let randomNum = Int(random()) % guild.members.count
        #endif
        let randomIndex = members.index(members.startIndex, offsetBy: randomNum)
        let randomMember = members[randomIndex]
        let name = randomMember.nick ?? randomMember.user.username

        message.channel?.send(DiscordMessage(content: "\(name) is \(arguments.joined(separator: " "))"))
    }

    func handleJoin(with arguments: [String], message: DiscordMessage) {
        let channel: DiscordGuildChannel
        let result = voiceChannelCheck(name: arguments.joined(separator: " "), message: message)

        switch result {
        case let .fine(voiceChannel):
            channel = voiceChannel
        case .notFound:
            message.channel?.send("I couldn't find a voice channel with that name.")
            return
        case .permissionFail:
            message.channel?.send("You don't have permission to let me join that channel.")
            return
        }

        youtubeQueue[message.channel!.guild!.id] = []

        client.joinVoiceChannel(channel.id)
    }

    func handleLeave(with arguments: [String], message: DiscordMessage) {
        let result = voiceChannelCheck(name: arguments.joined(separator: " "), message: message)

        switch result {
        case .fine:
            break
        case .notFound:
            message.channel?.send("I couldn't find a voice channel with that name.")
            return
        case .permissionFail:
            message.channel?.send("You don't have permission to let me leave that channel.")
            return
        }

        client.leaveVoiceChannel(onGuild: message.channel?.guild?.id ?? "")
    }

    func handleForecast(with arguments: [String], message: DiscordMessage) {
        guard !orphaned else {
            message.channel?.send("This shard is currently orphaned, and can't make forecasts.")

            return
        }

        let tomorrow = arguments.last == "tomorrow"
        let location: String

        if tomorrow {
            location = arguments.dropLast().joined(separator: " ")
        } else {
            location = arguments.joined(separator: " ")
        }

        bot.tokenCall(.weather) {canWeather in
            guard canWeather else {
                message.channel?.send("Weather is rate limited right now!")

                return
            }

            guard let forecast = getForecastData(forLocation: location),
                  let embed = createForecastEmbed(withForecastData: forecast, tomorrow: tomorrow) else {
                message.channel?.send("Something went wrong with getting the forecast data")

                return
            }

            message.channel?.send(DiscordMessage(content: "", embeds: [embed]))
        }
    }

    func handleMyRoles(with arguments: [String], message: DiscordMessage) {
        let roles = getRolesForUser(message.author, on: message.channelId)

        message.channel?.send(DiscordMessage(content: "Your roles: \(roles.map({ $0.name }))"))
    }

    func handleSkip(with arguments: [String], message: DiscordMessage) {
        guard let guild = message.channel?.guild,
              let member = guild.members[message.author.id],
              let channelId = client.voiceManager.voiceStates[guild.id]?.channelId,
              let channel = client.findChannel(fromId: channelId) as? DiscordGuildChannel,
              channel.canMember(member, .moveMembers) else {

            return
        }

        do {
            try client.voiceManager.voiceEngines[message.channel?.guild?.id ?? ""]?.requestNewEncoder()
        } catch {
            message.channel?.send("Something went wrong trying to skip")
        }
    }

    func handleStats(with arguments: [String], message: DiscordMessage) {
        getStats {stats in
            message.channel?.send(DiscordMessage(content: "", embeds: [createFormatMessage(withStats: stats)]))
        }
    }

    func handleTalk(with arguments: [String], message: DiscordMessage) {
        guard !orphaned else {
            message.channel?.send("This shard is currently orphaned, and is too depressed to talk.")

            return
        }

        bot.tokenCall(.cleverbot) {canTalk in
            guard canTalk else {
                message.channel?.send("Cleverbot is currently being ratelimited")

                return
            }

            self.cleverbot.say(arguments.joined(separator: " ")) {answer in
                message.channel?.send(DiscordMessage(content: answer))
            }
        }
    }

    func handleTopic(with arguments: [String], message: DiscordMessage) {
        message.channel?.modifyChannel(options: [.topic(arguments.joined(separator: " "))])
    }

    func handleWeather(with arguments: [String], message: DiscordMessage) {
        guard !orphaned else {
            message.channel?.send("This shard is currently orphaned, and can't check the weather.")

            return
        }

        bot.tokenCall(.weather) {canWeather in
            guard canWeather else {
                message.channel?.send("Weather is rate limited right now!")

                return
            }

            guard let weatherData = getWeatherData(forLocation: arguments.joined(separator: " ")),
                  let embed = createWeatherEmbed(withWeatherData: weatherData) else {
                message.channel?.send("Something went wrong with getting the weather data")

                return
            }

            message.channel?.send(DiscordMessage(content: "", embeds: [embed]))
        }
    }

    func handleWolfram(with arguments: [String], message: DiscordMessage) {
        guard !orphaned else {
            message.channel?.send("This shard is currently orphaned, and can't check wolfram.")

            return
        }

        bot.tokenCall(.wolfram) {canWolfram in
            guard canWolfram else {
                message.channel?.send("Wolfram is rate limited right now!")

                return
            }

            let result = getSimpleWolframAnswer(forQuestion: arguments.joined(separator: "+"))

            message.channel?.send(DiscordMessage(content: result))
        }
    }

    func handleYoutube(with arguments: [String], message: DiscordMessage) {
        message.channel?.send(playYoutube(channelId: message.channelId, link: arguments[0]))
    }
}

fileprivate extension Shard {
    func voiceChannelCheck(name: String, message: DiscordMessage) -> VoiceChannelCheckResult {
        guard let channel = findVoiceChannel(from: name, in: client.guildForChannel(message.channelId)) else {
            return .notFound
        }

        guard let member = channel.guild?.members[message.author.id], channel.canMember(member, .moveMembers) else {
            return .permissionFail
        }

        return .fine(channel)
    }
}
