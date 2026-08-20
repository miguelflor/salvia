# Salvia

> 🚧 This project is under construction.

## Overview

Salvia is a language designed for distributed algorithms.

### What makes it distributed

Like Go, it's possible to send messages through a special type, in Go it's a channel, in Salvia it's a `trigger`.
What makes it distributed is the `<~` operator, which sends messages to processes on other machines through RPC.
To make it closer to the pseudocode used in distributed algorithms, incoming messages are handled through a special `upon` function that activates when a message arrives.

## Example

Best-effort broadcast using Salvia's interfaces, triggers, and RPC messaging:

```svl
struct Message {
    msg: string,
}


interface Broadcast {
    init: proc() Broadcast,
    send: proc(Message),
    getDeliver: proc() trigger[Message],
    upon(<~Message),
}

protocol BebBroadcast impl Broadcast{
    ids: set[id],
    delieverBeb: trigger[Message],

    proc init() BebBroadcast {
        BebBroadcast{ids: Self.ids, delieverBeb: init(trigger[Message])}
    }

    proc getDeliver() trigger[Message] {
        self.delieverBeb
    }

    proc send(msg Message) {
        let msg = Message{ msg: "something" }; // ; behaves like rust
        .{id <~ msg : id in self.ids} // <~ is to make a message through RPC
    }

    upon <~(msg Message) {
        self.delieverBeb <- msg; // <- to activate the trigger
    }
}
```

## Roadmap

- [x] lexer, for a MVP version
- [x] parser , for a MVP version
- [ ] type checker , for a MVP version ( in progress ...)
- [ ] compiler , for a MVP version

