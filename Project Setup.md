# Install Aptos CLI (if not already)
curl -fsSL https://aptos.dev/scripts/install_cli.py | python3

# Create new Move project
aptos move new pixel_pet_game
cd pixel_pet_game

# Replace Move.toml with this
cat > Move.toml << EOF
[package]
name = "PixelPet"
version = "1.0.0"
authors = ["your-address-here"]

[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework", rev = "main" }
EOF
