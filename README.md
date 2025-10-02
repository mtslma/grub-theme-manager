# GRUB Theme Manager

A simple command-line tool to manage your GRUB bootloader themes. It allows you to download, install, activate, and remove themes through an easy-to-use interactive menu.

### Requirements

- A Linux operating system using GRUB 2.
- The script requires `git`, `curl`, `jq`, `fzf`, and `wget`. It will try to install these for you, but if that fails, you may need to install them manually using your system's package manager.

### Installation

**1. Clone the Repository**

Open a terminal and clone the project to your computer.

```bash
git clone https://github.com/mtslma/grub-theme-manager.git
```

**2. Enter the Directory**

Navigate into the folder you just cloned.

```bash
cd grub-theme-manager
```

**3. Set Permissions**

Make the installer and uninstaller scripts executable. This is a required step.

```bash
chmod +x install.sh uninstall.sh
```

**4. Run the Installer**

Execute the installation script with `sudo` to set everything up.

```bash
sudo ./install.sh
```

This will create a universal command and an application menu shortcut.

### Usage

After installation, you can run the manager in two ways:

1.  **From the Terminal**
    Just type the command:

    ```bash
    grub-theme-manager
    ```

2.  **From the Application Menu**
    Search for "GRUB Theme Manager" in your system's application launcher.

### Uninstallation

To remove the manager from your system, navigate back to the project folder and run the `uninstall.sh` script.

```bash
sudo ./uninstall.sh
```

<p align="center">
  <img src="https://github.com/Coopydood/ultimate-macOS-KVM/assets/39441479/39d78d4b-8ce8-44f4-bba7-fefdbf2f80db" width="10%"> </img>
</p>
