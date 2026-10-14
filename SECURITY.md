# Security

Still is a display utility, not a security boundary. macOS controls authentication. A full-screen preview never means a computer is locked. Only macOS screen-saver/password settings protect the session.

The app needs no Accessibility, Screen Recording, administrator, or network permissions. Installation writes the screen saver only in the current user’s Library. The optional login item uses Apple’s ServiceManagement API.

Do not post credentials, personal logs, or private screenshots in an issue. Report security concerns using the repository owner’s private GitHub contact/security reporting route if available. For a private repository, restrict reports to its trusted collaborators.

Current downloadable builds are ad-hoc signed and are not notarized. SHA-256 checksums detect accidental corruption; they do not substitute for a trusted signing identity. Never disable Gatekeeper, SIP, or password protection to use Still.
