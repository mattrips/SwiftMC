# Documentation

## Server configuration

The game version and server port are required. All other options are optionals.

```swift
// Basic configuration
let configuration = Configuration(protocolVersion: ProtocolConstants.minecraft_1_15_2, port: 25565)

// Add custom options
configuration.slots = 100 // Number of slots
configuration.motd = "§aMy beautiful server" // Server MOTD

// Give the configuration to your server
let server = SwiftMC(configuration: configuration)

// Do some customization (see next sections)
// ...

// Start the server
DispatchQueue.global().async {
    server.start()
}

// Read commands from console
while let input = readLine(strippingNewline: true) {
    server.dispatchCommand(command: input)
}
```

## Load a world

The first thing to know is that there are two types of worlds: `local` and `remote`. Local worlds are running locally on the server, while remote worlds are connected to a remote server (it can be a spigot server for example).

```swift
// Load a local world
server.registerLocalWorld(name: "world")

// Load a remote world
server.registerRemoteWorld(host: "123.123.123.123", port: 25565)
```

Note: The local world will create a folder at your SwiftMC server root.

## Register a custom command

For each command you want to register, you need to create a class conforming to `Command`:

```swift
public class MyCommand: Command {
    
    public func execute(server: SwiftMC, sender: CommandSender, args: [String]) {
        // Run your command here
        
    }
    
    public func description() -> String {
        // Give a description of your command, shown in the /help
        return "A custom command"
    }
    
}
```

Then, you need to register you command just before starting your server:

```swift
// Register your command as /mycommand
server.registerCommand("mycommand", command: MyCommand())
```

## Listen for events

```swift
// TODO
```
