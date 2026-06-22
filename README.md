# Eclipse Vale: Neon Oath — Indie Game Landing Page

A polished, cinematic, dark neon indie game landing page built with static HTML, Tailwind CSS CDN, custom CSS, and vanilla JavaScript.

This project is ready for GitHub Pages and Vercel.

## Features

- Cinematic hero section
- Premium glowing **Download Now** button
- Particle-like animated background
- Neon cyber/fantasy visual style
- Game features section
- Screenshot gallery
- Lore/story section
- System requirements
- Footer with fake studio/social links
- Safe downloadable PowerShell placeholder file

## Project Structure

```text
game-landing-page/
├── index.html
├── README.md
├── downloads/
│   └── Game_Launcher.ps1
├── assets/
│   ├── images/
│   │   ├── screenshot-1.jpg
│   │   ├── screenshot-2.jpg
│   │   └── screenshot-3.jpg
│   └── icons/
└── LICENSE
```

## How the Download Button Works

The main download button uses a simple static link:

```html
<a href="downloads/Game_Launcher.ps1" download="Game_Launcher.ps1">
  Download Now
</a>
```

This means:

- The file downloads only after the user clicks the button.
- The file does not auto-run.
- The file path is easy to replace.
- GitHub Pages supports this because it is a static file.

## How to Change the Download File

1. Put your file inside the `downloads/` folder.
2. Update the link in `index.html`.

Example:

```html
href="downloads/Your_File_Name.ps1"
download="Your_File_Name.ps1"
```

## How to Replace Screenshots

Replace these files with your own game screenshots:

```text
assets/images/screenshot-1.jpg
assets/images/screenshot-2.jpg
assets/images/screenshot-3.jpg
```

Recommended image size: `1600x900px`.

## How to Edit Game Text

Open `index.html` and search for comments like:

```html
<!-- EDIT GAME TITLE HERE -->
<!-- EDIT GAME DESCRIPTION HERE -->
<!-- EDIT DOWNLOAD PATH HERE -->
<!-- EDIT SOCIAL LINKS HERE -->
```

These comments show where to customize:

- Game title
- Description
- Download button text
- Screenshot paths
- Colors
- Footer studio name
- Social links

## Technologies Used

- HTML5
- Tailwind CSS via CDN
- Custom CSS
- Vanilla JavaScript
- Static files only

## GitHub Pages Compatibility

This website works on GitHub Pages because:

- All paths are relative.
- There is no backend.
- There are no build tools.
- The download file is stored inside the repository.
- Tailwind CSS is loaded through CDN.

## Vercel Compatibility

This project can be deployed on Vercel as a static HTML site.

Recommended settings:

- Framework Preset: Other
- Build Command: empty
- Output Directory: `.`
- Install Command: empty

## Safety Note About the PowerShell File

`downloads/Game_Launcher.ps1` is a safe placeholder script. It only prints demo text and waits for the user to press Enter.

It does not:

- Install software
- Download remote files
- Change system settings
- Auto-run
- Hide any actions

Replace it only with code you understand and trust.

## License

This project uses the MIT License. See `LICENSE` for details.
