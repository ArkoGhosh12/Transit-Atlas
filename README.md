# Transit Atlas

[Open the live Signal Lab](https://transit-atlas-signal-lab.toastybetta8193.chatgpt.site)

An interactive CSE / AI–ML project that classifies the shape of a star’s light curve. Select a simulated observation or upload a CSV, inspect its brightness over one orbital cycle, and save the classification to an experiment log. The interface works on phones and desktops.

![Transit Atlas signal workspace showing a simulated planetary transit and its classification](docs/signal-lab.webp)

| Edition | Where the classifier runs | Where saved runs live |
| --- | --- | --- |
| Full-stack app | Node.js server | SQLite on the server, linked to an anonymous browser cookie |
| GitHub Pages demo | Visitor’s browser | Local storage in that browser |

Both editions use the same classifier. Each keeps the latest 30 runs per browser. A different browser or device starts its own log.

## Run the full-stack app

Install Node.js 24 or later. Open a terminal in the directory containing `package.json` and run the following commands. The project uses Node’s built-in HTTP and SQLite modules, so there are no npm packages to install. [Node.js SQLite reference](https://nodejs.org/download/release/latest-v24.x/docs/api/sqlite.html)

```sh
npm test
npm start
```

Open **http://localhost:3000**. Choose **TA-0412**, run the classifier, save the result, then open **Experiment Log** and refresh. The server creates `data/experiments.sqlite` on first startup. Restart the server and reopen the same address in the same browser to revisit your run.

| Setting | Default | Purpose |
| --- | --- | --- |
| `HOST` | `127.0.0.1` | Address the server listens on |
| `PORT` | `3000` | HTTP port |
| `DATA_DIR` | `./data` | Directory containing the SQLite database |
| `PUBLIC_ORIGIN` | Automatic | Set this to the external HTTPS origin when deploying behind a reverse proxy |

### Open it on your phone over Wi-Fi

Connect both devices to the same private Wi-Fi network. Stop the running server with Ctrl+C. On Windows, run the following in PowerShell from the project directory.

```powershell
ipconfig
$env:HOST = "0.0.0.0"
npm start
```

Find the **IPv4 Address** under the active Wi-Fi adapter in the `ipconfig` output. If it is `192.168.1.23`, open **http://192.168.1.23:3000** on the phone. If Windows prompts for network access, allow Node.js on the private network. On macOS or Linux, find your Wi-Fi IPv4 address in network settings and start the server with `HOST=0.0.0.0 npm start`. The PC must stay on while serving a local session.

## Publish the public GitHub Pages demo

1. On GitHub, create an empty **public** repository called **transit-atlas**. Leave the README initialization option unchecked.
2. In **Settings → Pages → Build and deployment**, choose **GitHub Actions** as the source.
3. Run the commands below from the extracted project directory, replacing `YOUR-USERNAME` with your GitHub username. Commit the project files themselves so `package.json` and `.github/` sit at the repository root.
4. In **Actions**, open **Publish Transit Atlas to GitHub Pages** and wait for the deploy job to finish. If you enabled Pages after your first push, select **Run workflow** on the main branch.
5. Copy the published URL from **Settings → Pages** and add it to your repository’s **About → Website** field. With the repository name above, a standard project site opens at `https://YOUR-USERNAME.github.io/transit-atlas/`. Share that link with classmates on either phone or desktop. [GitHub Pages publishing settings](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) · [GitHub Pages workflow reference](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)

```sh
git init -b main
git add .
git commit -m "Build Transit Atlas exoplanet signal lab"
git remote add origin https://github.com/YOUR-USERNAME/transit-atlas.git
git push -u origin main
```

The workflow runs the tests, builds the browser edition with `npm run build:pages`, and publishes the resulting `dist/` directory. In this edition, the uploaded observations and saved runs stay in the visitor’s browser. Clearing site storage removes that browser’s runs.

## Deploy the public app with SQLite

### Test the container locally

From the project directory, build the image and mount a named volume at `/data`. The server runs as the unprivileged `node` user. [Docker volume reference](https://docs.docker.com/engine/storage/volumes/)

```sh
docker build -t transit-atlas .
docker volume create transit-atlas-data
docker run --name transit-atlas --rm -p 127.0.0.1:3000:3000 --mount source=transit-atlas-data,target=/data transit-atlas
```

Open **http://localhost:3000** and save a run. Stop the container with Ctrl+C, repeat the `docker run` command, and reload the same page. The named volume retains the database.

### Publish from the repository on Render

1. In Render, create a **Web Service** and connect the GitHub repository. Select the **Docker** runtime, the **main** branch, and the repository root containing the Dockerfile.
2. Choose a paid service that supports a persistent disk. Add the disk at **`/data`**, leave the Docker start command at its default, and use a single instance. The image sets `HOST=0.0.0.0` and `DATA_DIR=/data`. The app accepts the host’s `PORT` setting.
3. Deploy the service. In the service’s environment settings, set **`PUBLIC_ORIGIN`** to the exact public HTTPS origin shown in the dashboard, such as `https://your-service.onrender.com`. Save the change and deploy it. Update this value if you switch to a custom domain.
4. Open that public URL on desktop and mobile. Save a run, redeploy, and reopen the same address in the same browser to check persistence. Render provides TLS at its public hostname and preserves files under the configured disk mount. [Render web service guide](https://render.com/docs/web-services) · [Render persistent disk guide](https://render.com/docs/disks)

## Reproduce the ML experiment

All four demo observations have fictional identifiers. The classifier learns from 192 seeded synthetic curves divided evenly among **Planet transit**, **Eclipsing binary**, **Stellar variability**, and **Noise**. The holdout uses a separate set of seeds and 24 examples per class.

1. Normalize flux by its median and interpolate one orbit onto a 96-point periodic grid.
2. Measure seven features describing brightness range, dip depth, asymmetry, the depth of the opposite-phase dip, roughness, dip duration, and the interquartile range. Standardize features with the training-set means and standard deviations.
3. Find the seven closest training examples by Euclidean distance. Each neighbor votes with weight proportional to inverse distance. **Neighbor agreement** reports the winning class’s share of those weighted votes.

The holdout result is **93/96 correct (96.9%)**. Two simulated eclipsing binaries received the planet-transit label and one simulated planet transit received the noise label. All training and test curves share the same generator assumptions. Real observations introduce additional instrument effects and astrophysical signals. The vote share measures agreement within this model and cannot establish a planet’s presence.

Use this command to print the evaluation, including the confusion matrix. Rows are the true classes and columns are the predicted classes, in the order listed in the result.

```sh
node --input-type=module -e "import { evaluate } from './lib/model.mjs'; console.log(evaluate())"
```

### Upload your own signal

Start with [the complete 161-row example CSV](public/example-transit.csv). Use two columns, `phase,flux`, with one observation per line and an optional header. Use 32–2048 distinct phase values covering 0.75–1.0 orbital cycles and positive, finite flux values. The upload limit is 256 KiB. A complete cycle can span −0.5 to +0.5 or 0 to 1. Fold time measurements to phase using a known period before uploading.

## Architecture

| Component | Location | Responsibility |
| --- | --- | --- |
| Responsive frontend | `public/` | Page layout, signal plot, uploads, predictions and experiment history |
| ML model | `lib/model.mjs` | Synthetic data, CSV parsing, feature extraction, training, inference and evaluation |
| HTTP API | `server/` | Validated requests, inference, cookie-scoped experiment storage |
| SQLite schema | `database/schema.sql` | Experiment ID, owner hash, name, timestamp, observations and classification |
| Automated tests | `tests/` | Check model and application behavior |
| Static build and deployment | `scripts/build-pages.mjs`, `.github/workflows/pages.yml` | Package and publish the GitHub Pages edition |

### HTTP endpoints

| Method | Path | Input / result |
| --- | --- | --- |
| GET | `/api/samples` | Four simulated signals and their observations |
| GET | `/api/model` | Holdout performance, class names and confusion matrix |
| POST | `/api/classify` | Send `{"points":[...]}` to receive a label, weighted votes and measured features |
| POST | `/api/runs` | Send `{"name":"My run","points":[...]}` to classify and save a run |
| GET | `/api/runs` | Read saved runs associated with the current browser cookie |

For POST requests, set `Content-Type: application/json`. Each observation has numeric `phase` and `flux` fields. In the server edition, the backend recalculates the prediction for each saved run. Clearing the cookie makes earlier server runs inaccessible from that browser.

<details>
<summary>About the planet artwork</summary>

The hero image in [public/assets/transit-hero.webp](public/assets/transit-hero.webp) is an artist’s impression generated with the built-in ImageGen tool. Its brief was a cinematic ultrawide observatory banner with a dark, ringed gas giant at the right, a thin amber crescent, subtle copper dust, and a quiet star field at the left for the title. The plotted observations come from the numerical simulator.

</details>

