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
    ids set[id], // private by default, accessible only through its own namespace
    delieverBeb trigger[Message],
}

impl Broadcast for BebBroadcast {

    fn init() {
        return BebBroadcast{ids: Self.ids, delieverBeb: init(trigger[Message])};
    }

    fn getDeliver(self) {
        self.delieverBeb
    }

    fn send(self, msg Message) {
        msg = Message{ msg: "something" }; // ; behaves like Rust
        {id <~ msg : id in self.ids} // <~ sends a message through RPC
    }

    upon <~(msg Message) {
        delieverBeb <- msg; // <- activates the trigger
    }
}
```

## Roadmap

- [ ] lexer, with simple code
- [ ] parser , with simple code
- [ ] type checker , with simple code
- [ ] compiler , with simple code

