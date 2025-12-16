import os
import sys
from typing import Dict, List, Any, Optional
from http.cookiejar import DefaultCookiePolicy
import logging
from pathlib import Path
import requests
import yaml

logger = logging.getLogger(__name__)

DEFAULT_PAGE_SIZE = 100
DEFAULT_STORAGE_LIMIT = -1
DEFAULT_DURATION = -1

class HarborConfigurator:
    """
    Harbor API client for managing registries, projects, and robot accounts.

    This class provides methods to interact with Harbor's REST API for creating
    and updating configuration resources. It handles authentication, SSL verification,
    and provides high-level operations for Harbor resource management.

    Attributes:
        url (str): Base URL of the Harbor instance
        session (requests.Session): HTTP session with authentication configured
    """
    def __init__(self, url: str, username: str, password: str):
        self.url = url.rstrip('/')
        self.session = requests.Session()
        self.session.auth = (username, password)
        verify_ssl = os.getenv('HARBOR_VERIFY_SSL', 'true').lower()
        self.session.verify = verify_ssl in ('true', '1', 'yes')
        # Disable cookie policy to avoid issues with CSRF tokens
        self.session.cookies.set_policy(DefaultCookiePolicy(allowed_domains=[]))

        logger.info("Harbor client initialized")

    def get_registries(self) -> Dict[str, int]:
        """Get existing registries as a dict mapping name to ID"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/registries")
            response.raise_for_status()
            registries = response.json()
            return {r['name']: r['id'] for r in registries}
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting registries: %s", e)
            raise

    def get_registry_id(self, project_name: str) -> Optional[int]:
        """Get registry ID associated with a proxy cache project"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/projects/{project_name}")
            response.raise_for_status()
            project = response.json()
            return project.get('registry_id', None)
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting project '%s': %s", project_name, e)
            raise

    def create_registry(self, registry: Dict[str, Any]) -> Optional[int]:
        """Create new registry, returns registry ID"""
        registry_name = registry['name']

        data = {
            "name": registry_name,
            "type": registry.get('type', ''),
            "url": registry.get('url',''),
            "description": registry.get('description', ''),
            "insecure": registry.get('insecure', False)
        }

        # Add credential if provided
        if 'credential' in registry:
            data['credential'] = registry['credential']

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/registries",
                json=data
            )
            response.raise_for_status()

            # Harbor returns 201 with Location header, no response body
            registry_id = None
            location = response.headers.get('Location')
            if location:
                # Extract ID from Location header like "/api/v2.0/registries/1"
                try:
                    registry_id = int(location.rstrip('/').split('/')[-1])
                except (ValueError, IndexError):
                    logger.warning("Could not parse registry ID from Location: %s", location)

            # Fallback: fetch registry list to get ID
            if not registry_id:
                updated_registries = self.get_registries()
                registry_id = updated_registries.get(registry_name)

            if not registry_id:
                logger.error("Could not determine ID of created registry '%s'", registry_name)
                raise RuntimeError("Registry ID not found after creation")

            logger.info("Created registry '%s' (ID: %s)", registry_name, registry_id)
            return registry_id
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating registry '%s': %s", registry_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def update_registry(self, registry_id: int, registry: Dict[str, Any]) -> bool:
        """Update existing registry, returns bool success"""
        registry_name = registry['name']

        data = {
            "name": registry_name,
            "type": registry.get('type', ''),
            "url": registry.get('url',''),
            "description": registry.get('description', ''),
            "insecure": registry.get('insecure', False)
        }

        # Add credential if provided
        if 'credential' in registry:
            data['credential'] = registry['credential']

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/registries/{registry_id}",
                json=data
            )
            response.raise_for_status()
            logger.info("Updated registry '%s' (ID: %s)", registry_name, registry_id)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating registry '%s': %s", registry_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def get_projects(self) -> List[str]:
        """Get existing project names"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/projects")
            response.raise_for_status()
            return [p['name'] for p in response.json()]
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting projects: %s", e)
            raise

    def create_project(self, project: Dict[str, Any], registry_id: int = None) -> bool:
        """Create new project"""
        project_name = project['name']

        data = {
            "project_name": project_name,
            "metadata": {
                "public": str(project.get('public', False)).lower(),
                "auto_scan": str(project.get('auto_scan', True)).lower(),
                "severity": project.get('severity', 'low'),
                "enable_content_trust": str(project.get('enable_content_trust', False)).lower(),
                "reuse_sys_cve_allowlist": str(project.get('reuse_sys_cve_allowlist', True)).lower(),
            },
            "storage_limit": project.get('storage_quota', -1)
        }

        # Add optional registry_id for proxy cache projects
        if registry_id:
            data['registry_id'] = registry_id

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/projects",
                json=data
            )
            response.raise_for_status()
            logger.info("Created project '%s'%s", project_name, f" (proxy cache for registry ID {registry_id})" if registry_id else "")
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating project '%s': %s", project_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def update_project(self, project: Dict[str, Any]) -> bool:
        """Update existing project"""
        project_name = project['name']

        # Note: registry_id is immutable after creation, so not included here
        data = {
            "metadata": {
                "public": str(project.get('public', False)).lower(),
                "auto_scan": str(project.get('auto_scan', True)).lower(),
                "severity": project.get('severity', 'low'),
                "enable_content_trust": str(project.get('enable_content_trust', False)).lower(),
                "reuse_sys_cve_allowlist": str(project.get('reuse_sys_cve_allowlist', True)).lower(),
            },
            "storage_limit": project.get('storage_quota', -1)
        }

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/projects/{project_name}",
                json=data
            )
            response.raise_for_status()
            logger.info("Updated project '%s'", project_name)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating project '%s': %s", project_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def get_system_robots(self) -> Dict[str, int]:
        """Get existing system-level robot accounts as dict mapping name to ID"""
        try:
            all_robots = {}
            page = 1
            page_size = DEFAULT_PAGE_SIZE

            while True:
                response = self.session.get(
                    f"{self.url}/api/v2.0/robots",
                    params={"page": page, "page_size": page_size}
                )
                response.raise_for_status()
                robots = response.json()

                if not robots:
                    break

                for r in robots:
                    all_robots[r.get('name', '')] = r.get('id')
                page += 1

            return all_robots
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting system robots: %s", e)
            raise

    def get_robot_secret(self, robot_name: str, secret_dir: Path) -> str:
        """Load predefined secret from file named after robot """

        secret_file = secret_dir / robot_name
        if not secret_file.exists():
            logger.error("Secret file not found for robot '%s': %s", robot_name, secret_file)
            raise FileNotFoundError(f"Required secret file not found: {secret_file}")

        try:
            robot_secret = secret_file.read_text().strip()
            if not robot_secret:
                logger.error("Secret file is empty for robot '%s': %s", robot_name, secret_file)
                raise ValueError(f"Secret file is empty: {secret_file}")
            logger.info("Loaded secret for robot '%s' from %s", robot_name, secret_file)
            return robot_secret
        except (FileNotFoundError, ValueError):
            raise
        except Exception as e:
            logger.error("Failed reading secret file %s: %s", secret_file, e)
            raise

    def update_robot(self, robot_id: int, robot: Dict[str, Any], secret_dir: Path) -> bool:
        """Update existing robot account"""
        robot_name = robot['name']
        robot_secret = self.get_robot_secret(robot_name, secret_dir)

        data = {
            "name": f"robot${robot_name}", # cannot change name
            "description": robot.get('description', ''),
            "duration": robot.get('duration', -1),
            "permissions": robot.get('permissions', []),
            "level": "system", # cannot change level
            "secret": robot_secret
        }

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/robots/{robot_id}",
                json=data
            )
            response.raise_for_status()
            logger.info("Updated robot '%s' (ID: %s)", robot_name, robot_id)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating robot '%s': %s", robot_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def create_robot(self, robot: Dict[str, Any], secret_dir: Path) -> Optional[Dict[str, str]]:
        """Create new system-level robot account"""
        robot_name = robot['name']
        robot_secret = self.get_robot_secret(robot_name, secret_dir)

        data = {
            "name": robot_name,
            "description": robot.get('description', ''),
            "duration": robot.get('duration', -1),
            "level": "system",
            "disable": False,
            "permissions": robot.get('permissions', []),
            "secret": robot_secret
        }

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/robots",
                json=data
            )
            response.raise_for_status()
            result = response.json()

            logger.info("Created robot '%s'", robot_name)

            return {
                'name': result['name'],
                'secret': result['secret'],
                'token': result.get('token', '')
            }
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating robot '%s': %s", robot_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

def main() -> None:
    """
    Configure Harbor by creating projects and robot accounts from YAML config files.

    Requires environment variables:
    - HARBOR_URL: Harbor instance URL
    - HARBOR_ADMIN_PASSWORD: Admin password
    - HARBOR_ADMIN_USER: Admin username (default: 'admin')
    - HARBOR_VERIFY_SSL: SSL verification (default: 'true')
    - LOG_LEVEL: Logging level (default: 'INFO', options: DEBUG, INFO, WARNING, ERROR, CRITICAL)
    - CONFIG_DIR: Directory containing config files (default: '/config')
    - SECRET_DIR: Directory containing robot secret files (default: '/secrets')
    """
    # Configure logging
    log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    logging.basicConfig(
        level=getattr(logging, log_level, logging.INFO),
        format='%(message)s'
    )

    harbor_url = os.getenv('HARBOR_URL')
    admin_user = os.getenv('HARBOR_ADMIN_USER', 'admin')
    admin_pass = os.getenv('HARBOR_ADMIN_PASSWORD')
    config_dir = Path(os.getenv('CONFIG_DIR', '/config'))
    secret_dir = Path(os.getenv('SECRET_DIR', '/secrets'))

    if not harbor_url or not admin_pass:
        logger.error("HARBOR_URL and HARBOR_ADMIN_PASSWORD must be set")
        sys.exit(1)

    logger.info("🌊 Configuring Harbor at %s", harbor_url)
    logger.info("   Admin user: %s", admin_user)
    logger.info("   Config dir: %s", config_dir)
    try:
        harbor = HarborConfigurator(harbor_url, admin_user, admin_pass)
    except Exception as e:
        logger.error("Failed to initialize Harbor client: %s", e)
        sys.exit(1)

    # Load and apply projects
    projects_created = 0
    projects_updated = 0
    registries_created = 0
    registries_updated = 0
    try:
        with open(config_dir / 'projects.yaml', encoding='utf-8') as f:
            projects = yaml.safe_load(f) or []
            logger.info("\n📦 Processing projects and registries...")
            existing_projects = harbor.get_projects()
            for project in projects:
                project_name = project['name']
                registry_id = None
                registry = project.get('registry', None)
                if project_name in existing_projects:
                    if registry:
                        registry_id = harbor.get_registry_id(project_name)
                        if registry_id:
                            if harbor.update_registry(registry_id, registry):
                                registries_updated += 1
                        else:
                            logger.warning("Ignoring registry configurations for project '%s' because it exists and is not a proxy cache project", project_name)
                    if harbor.update_project(project):
                        projects_updated += 1
                else:
                    if registry:
                        registry_id = harbor.create_registry(registry)
                        if registry_id:
                            registries_created += 1
                    if harbor.create_project(project, registry_id):
                        projects_created += 1
    except FileNotFoundError:
        logger.warning("⚠️  No projects.yaml found, skipping projects")
    except Exception as e:
        logger.error("Failed processing projects: %s", e)
        sys.exit(1)

    # Load and apply robots
    robots_created = 0
    robots_updated = 0
    try:
        with open(config_dir / 'robots.yaml', encoding='utf-8') as f:
            robots = yaml.safe_load(f) or []
            logger.info("\n🤖 Processing robot accounts...")
            existing_robots = harbor.get_system_robots()
            for robot in robots:
                robot_name = "robot$" + robot['name']
                if robot_name in existing_robots:
                    robot_id = existing_robots[robot_name]
                    harbor.update_robot(robot_id, robot, secret_dir)
                    robots_updated += 1
                else:
                    if harbor.create_robot(robot, secret_dir):
                        robots_created += 1
    except FileNotFoundError:
        logger.warning("⚠️  No robots.yaml found, skipping robots")
    except Exception as e:
        logger.error("Failed processing robots: %s", e)
        sys.exit(1)

    # Summary
    logger.info("\n✅ Harbor configuration complete!")
    if projects_created > 0:
        logger.info("   Projects created: %s", projects_created)
    if projects_updated > 0:
        logger.info("   Projects updated: %s", projects_updated)
    if registries_created > 0:
        logger.info("   Registries created: %s", registries_created)
    if registries_updated > 0:
        logger.info("   Registries updated: %s", registries_updated)
    if robots_created > 0:
        logger.info("   Robots created: %s", robots_created)
    if robots_updated > 0:
        logger.info("   Robots updated: %s", robots_updated)

if __name__ == '__main__':
    main()
