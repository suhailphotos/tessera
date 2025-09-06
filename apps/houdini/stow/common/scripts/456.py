import hou
import sys

# List of environment variables to check
var_list = ['JOB', 'POSE', 'SHOTS', 'ASSETS']

# Folder lookup dictionary for different platforms
folder_lookup = {
    'DROPBOX': {
        'darwin': '/Users/suhail/Library/CloudStorage/Dropbox',
        'Windows': 'C:/Users/Suhail/Dropbox'
    },
    'USD_LIB': {
        'darwin': '/Users/suhail/Library/CloudStorage/Dropbox/threeD/lib/usd',
        'Windows': 'C:/Users/Suhail/Dropbox/threeD/lib/usd'
    },
    'COURSES': {
        'darwin': '/Users/suhail/Library/CloudStorage/Dropbox/threeD/courses',
        'Windows': 'C:/Users/Suhail/Dropbox/threeD/courses'
    },
    'PROJECTS': {
        'darwin': '/Users/suhail/Library/CloudStorage/Dropbox/threeD/projects',
        'Windows': 'C:/Users/Suhail/Dropbox/threeD/projects'
    }
}

# Determine the current platform
current_platform = 'darwin' if sys.platform == 'darwin' else 'Windows'
other_platform = 'Windows' if current_platform == 'darwin' else 'darwin'

# Function to update environment variables
def update_environment_variables():
    for var in var_list:
        # Get the current value of the environment variable
        current_value = hou.getenv(var)
        
        if current_value:
            # Iterate through the folder lookup dictionary to find and replace paths
            for key, paths in folder_lookup.items():
                # Check if the current value contains the other platform's path
                if paths[other_platform] in current_value:
                    # Update the environment variable to the current platform's path
                    new_value = current_value.replace(paths[other_platform], paths[current_platform])
                    hou.putenv(var, new_value)
                    break

# Call the function to update environment variables
update_environment_variables()

def fetch_parameter_values(input_index, parameter_name):
    import loputils
    node = hou.pwd().inputs()[input_index]
    return loputils.fetchParameterValues(node, parameter_name)

hou.session.fetch_parameter_values = fetch_parameter_values
