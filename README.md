# Chains

- Updated all the skillchain properties to the Horizon server.
- Corrected the SMN Blood Pact values.
- Disabled BST/SMN pet abilities that you can't skillchain.

### Active Battle Skillchain Display.

Displays a text object containing skillchain elements resonating on current target, timer for skillchain window and a list of weapon skills that can skillchain based on the weapon you have currently equipped.

Chains is based on the skillchains addon by Ivaar for Ashita-v3. It has mostly been recoded for Ashita-v4 while maintaining the same functionality.

### Commands
The following commands may be used:

    /chains help           -- Lists all available commands in chat.
    /chains color          -- Toggle colored skillchain properties.
    /chains weapon         -- Toggle weaponskill display.
    /chains pet            -- Toggle pet skill display.
    /chains spell          -- Toggle spell display.
    /chains ability        -- Toggle ability requirement for spell skill display.
    /chains smn            -- Toggles requirement for avatar to be summoned for pet skill display.
    /chains visible        -- Show live preview and unlock the window for moving.
    /chains direction      -- Toggle top-down or bottom-up layout direction.
    /chains scale <value>  -- Set UI font and window scale.
    /chains move <x> <y>   -- Set window position.
    /chains reset          -- Reset window position and direction.
    
### Acknowledgments
All credit goes to Ivaar for the original skillchains implementation which was used as the template for how to accomplish the desired results and how to deal with some of the corner cases.

Special thanks to Atom0s and Thorny. Many of their addons are used as examples of how to accomplish various tasks.

