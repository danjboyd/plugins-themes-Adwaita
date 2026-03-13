# AdwaitaDemo

`AdwaitaDemo` is the GNOME-side comparison harness for this repository.

It exists to give the GNUstep theme a concrete visual target instead of relying
on memory.

## Usage

Run the app:

```sh
python3 Reference/AdwaitaDemo/adwaita_demo.py
```

Open a specific page:

```sh
python3 Reference/AdwaitaDemo/adwaita_demo.py --page controls
python3 Reference/AdwaitaDemo/adwaita_demo.py --page stress
```

Dump measured widget metrics from the live Adwaita environment:

```sh
python3 Reference/AdwaitaDemo/adwaita_demo.py --dump-metrics
```

The current app depends on system-provided `PyGObject`, GTK4, and libadwaita.
