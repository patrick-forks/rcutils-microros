SHELL = /bin/zsh
PWD_DIR = "$(shell basename $$(pwd))"
SCRIPTS_DIR = "./scripts"
EMBD_V2_DIR = "./EMBD-v2-HighLevel"
SRC_DIR = "$(EMBD_V2_DIR)/src"
ROS2_UNDERLAY = "/opt/ros/humble/setup.zsh"
ROS2_OVERLAY = "$(EMBD_V2_DIR)/install/local_setup.zsh"
VEHICLE_INTERFACE_DIR = "$(SRC_DIR)/vehicle_interface"

# ==================================
# Pushes the current directory to remote host.
# ==================================

REMOTE_USER_HOST = "patrick@vm_comp4961_ubuntu2204"
REMOTE_DEST_DIR = "~/remote/$(shell hostname -s)/"

.PHONY: push-remote
push-remote:
	# Make the directory on the remote if it doesn't exist already.
	(ssh -t $(REMOTE_USER_HOST) "mkdir -p $(REMOTE_DEST_DIR)$(PWD_DIR)")
	# Sync our current directory with the remote.
	(rsync -a \
 			--delete \
 			--exclude "build" \
 			--exclude "install" \
 			--exclude "log" \
 			--exclude "build-remote" \
 			--exclude "cmake-build*" \
 			--exclude ".vscode" \
 			--exclude ".idea" \
 			--exclude ".git" \
 			--exclude ".gitignore" \
 			./ $(REMOTE_USER_HOST):$(REMOTE_DEST_DIR)$(PWD_DIR))

# ==================================
# Runs a Make command remotely.
# ==================================

.PHONY: remote
remote: push-remote
	ssh -t $(REMOTE_USER_HOST) "\
		cd $(REMOTE_DEST_DIR)$(PWD_DIR) ; \
		zsh -ilc 'make $(MAKE_CMD)' ; "

# ==================================
# Cleaning
# ==================================

.PHONY: clean
clean:
	cd $(EMBD_V2_DIR) && \
		rm -rf build install log

# ==================================
# Build
# ==================================

.PHONY: dependencies
dependencies:
	rosdep install -i --from-path $(SRC_DIR) --rosdistro humble -y

.PHONY: build
build: dependencies
	cd $(EMBD_V2_DIR) && \
		source $(ROS2_UNDERLAY) && \
		colcon build --parallel-workers 4

.PHONY: build-headlight-driver
build-headlight-driver:
	cd $(EMBD_V2_DIR) && \
		source $(ROS2_UNDERLAY) && \
		colcon build --packages-select headlight_driver

# ==================================
# Test
# ==================================

.PHONY: test-result
test-result:
	cd $(EMBD_V2_DIR) && \
		colcon test-result --all

.PHONY: test
test: build
	cd $(EMBD_V2_DIR) && \
		source $(ROS2_UNDERLAY) && \
		colcon test --ctest-args --rerun-failed --output-on-failure
	$(MAKE) test-result

.PHONY: test-headlight-driver
test-headlight-driver: build
	cd $(EMBD_V2_DIR) && \
		source $(ROS2_UNDERLAY) && \
		colcon test --packages-select headlight_driver --ctest-args --rerun-failed --output-on-failure
	$(MAKE) test-result | grep headlight_driver

# ==================================
# ROS2
# ==================================

.PHONY: ros2-env
ros2-env: build
	$(SCRIPTS_DIR)/ros2-env.sh

# =====================================
# Run
# =====================================

.PHONY: run
run: build
	source $(ROS2_UNDERLAY) && \
		source $(ROS2_OVERLAY) && \
		ros2 launch $(EMBD_V2_DIR)/launch/system_launch.xml

