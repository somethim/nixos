-- NixOS: language servers, formatters and linters come from Nix (modules/dev.nix),
-- so Mason doesn't download its own binaries; LazyVim finds the tools on PATH.
return {
	{ "mason-org/mason.nvim", enabled = false },
	{ "mason-org/mason-lspconfig.nvim", enabled = false },
	{ "jay-babu/mason-nvim-dap.nvim", enabled = false },
}
