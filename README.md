# kwinrulesrc-manager

Declaratively manage `kwinrulesrc`.


### discord log of bri's chat to the void on how this should work:

> -# _reads [the code for Nix plasma-manager's window-rules module](https://github.com/nix-community/plasma-manager/blob/b70be387276e632fe51232887f9e04e2b6ef8c16/modules/window-rules.nix) to try and make some sense of how this might work_
> 
> oh, that's kind of insane...
> 
> -# (please pardon my rubber ducking here)
> 
> so the file is per-user, in `~/.config/kwinrulesrc`, and it's basically an ini file with one section for each rule labeled with a UUID, as well as a `[General]` section with the keys, `count` set to the number of rules, and `rules` set to a comma-delimited list of rule UUIDs
> 
> for reference, my current `kwinrulesrc` with rules that i'd like to be managed by the distro itself: 
> 
> ```ini
> [8dfb437f-ac7b-4ada-8ab2-ff34d1f0dfe4]
> Description=Window settings for Quick Access — 1Password
> above=true
> aboverule=2
> desktops=\\0
> desktopsrule=2
> layer=popup
> layerrule=2
> placementrule=2
> skippager=true
> skippagerrule=2
> skipswitcher=true
> skipswitcherrule=2
> skiptaskbar=true
> skiptaskbarrule=2
> title=Quick Access — 1Password
> titlematch=1
> wmclass=1Password
> wmclassmatch=1
> 
> [General]
> count=2
> rules=c4111977-4c56-44b5-8db4-a75923b98988,8dfb437f-ac7b-4ada-8ab2-ff34d1f0dfe4
> 
> [c4111977-4c56-44b5-8db4-a75923b98988]
> Description=Application settings for org.kde.plasma.emojier
> above=true
> aboverule=2
> acceptfocus=true
> acceptfocusrule=2
> skippager=true
> skippagerrule=2
> skipswitcher=true
> skipswitcherrule=2
> skiptaskbar=true
> skiptaskbarrule=2
> wmclass=plasma-emojier org.kde.plasma.emojier
> wmclasscomplete=true
> wmclassmatch=1
> ```
> 
> So... what comes to mind is the following: first, i need a CRUD tool for the rules file, with an upsert method. then i need to export the rules i want to manage externally to files, which i guess i'd store in my custom image's rootfs. (e.g., files `/usr/lib/bri-custom-image/kwinrules.d/<UUID>.kwinrule` that each contain individual kwinrules).
> 
> that'll give me enough to import rules upon login or something.
> 
> but then ideally i'd actually do something to reconcile them (i.e., remove old rules as well) instead of just importing on login...
> 
> maybe the least insane way to do _that_ would be to have the reconciliation script work like this:
> 1. cache a copy of the distro rules into the home folder
> 2. generate a diff of which UUIDs were added and removed between the last cache and the current cache
> 3. drive the crud tool to remove any rules from kwinrulesrc that were removed from the cache
> 4. run the crud tool to upsert each rule that's in the cache into kwinrulesrc
> 5. tell kwin to reload kwinrulesrc
> 
>
> oh and that's annoying, kde's built-in kwinrules export doesn't save the UUIDs (using the description/name as the key instead), and doesn't overwrite anything with the same description/name
