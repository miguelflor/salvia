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
    send: proc(self, Message) (),
    getDeliver: proc(self) trigger[Message],
    upon(<~Message),
}

protocol BebBroadcast impl Broadcast{
    let ids: set[id]
    let delieverBeb: trigger[Message]

    proc init() {
        return BebBroadcast{ids: Self.ids, delieverBeb: init(trigger[Message])};
    }

    proc getDeliver() {
        self.delieverBeb
    }

    proc send(msg Message) {
        let msg = Message{ msg: "something" }; // ; behaves like rust
        {id <~ msg : id in self.ids} // <~ is to make a message through RPC
    }

    upon <~(msg Message) {
        self.delieverBeb <- msg; // <- to activate the trigger
    }
}
```

## Roadmap

- [x] lexer, with simple code
- [ ] parser , with simple code (In progress ...)
- [ ] type checker , with simple code
- [ ] compiler , with simple code

