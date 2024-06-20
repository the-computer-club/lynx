# Contribution Quick start

Lynx does **not contain**:
  - Any flake-inputs
  The reason for this is to provide a lightweight flake. We address a fundamental problem
  with inputs, and it is two fold. While locking the inputs of the final flake in use is desirable,
  `input.follow` statements rely on the good-will of those who write and use them, and can be problematic when 
  having many inputs, or inputs which you don't want to fork. Depth of inputs can problematic, including
  minimalist inputs which provide a single function, but reference nixpkgs, with no other utilities.
  Currently there is no way to remove/override an input's sub-input to deal with such issues.
  
  We propose this flake, to have no inputs to address these problems. 
  Instead, facilities use module loading to provide preinitialized variables. 
  Inputs which reference this input, if on the same commit-revision will not reproduce a new derivation, because there is no difference. 
 
  - Source code for your project (We'll host your build instructions though)
    You may reference your own code by using trivial fetchers like `pkgs.fetchGit`.
    
  - Nixos Configurations (Share your modules with us instead)
    Instead, you may write tests which we run on our CI
  
  - Does not use `self` (flake modules isolated)
    Availability to `self` isn't nessicary. We instead prefer you use flake-modules `options` to declare namespaced variables. 


