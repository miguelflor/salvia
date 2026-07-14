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
    msg string,
}


pub interface Broadcast {
    fn init() -> Broadcast,
    fn send(self, Message) -> (),
    fn getDeliver(self) -> trigger[Message],
}

struct BebBroadcast {
    ids set[id], // the user can't touch this by default accessing thourght a different namespace is private
    delieverBeb trigger[Message],
}

extend Broadcast with BebBroadcast{

    proc init() {
        return BebBroadcast{ids: Self.ids, delieverBeb: init(trigger[Message])};
    }

    proc getDeliver(self) {
        self.delieverBeb
    }

    proc send(self, msg Message) {
        msg = Message{ msg: "something" }; // ; behaves like rust
        {id <~ msg : id in self.ids} // <~ is to make a message through RPC
    }

    upon <~(msg Message) {
        delieverBeb <- msg; // <- to activate the trigger
    }
}
```

## Roadmap

- [x] lexer, with simple code
- [ ] parser , with simple code (In progress ...)
- [ ] type checker , with simple code
- [ ] compiler , with simple code

