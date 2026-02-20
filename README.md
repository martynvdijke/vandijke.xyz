# vandijke.xyz

This is the source code for my personal website, built using the [Hugo](https://gohugo.io/) static site generator.

## Prerequisites

Before you begin, ensure you have the following installed:

* [Hugo](https://gohugo.io/installation/) (extended version recommended)

## Getting Started

1. **Clone the repository:**

    ```bash
    git clone https://github.com/yourusername/vandijke.xyz.git
    cd vandijke.xyz
    ```

2. **Initialize submodules (if using a git-based theme):**

    ```bash
    git submodule update --init --recursive
    ```

3. **Run the development server:**

    ```bash
    hugo server -D
    ```

    The site will be available at `http://localhost:1313`.

## Project Structure

* `content/`: Where the Markdown files for pages and posts reside.
* `static/`: Static assets like images, favicons, and robots.txt.
* `themes/`: The website theme(s).
* `assets/`: Resources that require processing by Hugo Pipes (SCSS, JS).
* `congif.yaml` (or `config.toml`): The main configuration file.

## Deployment

The site is automatically built and deployed when changes are pushed to the `main` branch.

To build the site manually:

```bash
hugo
```

The static files will be generated in the `public/` directory.
