return {
	TOOLBAR_LABEL = "unroot's plugins";

	-- Plugin metadata
	PLUGIN_ICON = "";
	PLUGIN_TITLE = "Draw Visualizer - %s (%d)";
	PLUGIN_NAME = "Draw Visualizer";

	-- General configuration
	MAX_INSTANCE_DEPTH = 500;

	-- Plugin actions
	ACTIONS = {
		Toggle = {
			Name = "Toggle Draw Visualizer",
			Description = "Toggles the plugin window.",
			Action = function(target)
				if target then
					target.Enabled = not target.Enabled
				end
			end
		},

		Selection = {
			Name = "Target Selection",
			Description = "Enables/disables target selection.",
			Action = function(pane)
				if pane then
					pane:SetTargetSearchEnabled(true)
				end
			end
		}
	}
}
