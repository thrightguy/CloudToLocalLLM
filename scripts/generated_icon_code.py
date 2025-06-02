# Generated icon code for CloudToLocalLLM tray daemon
import base64

    def _get_icon_data(self, state: str = "idle") -> bytes:
        """Get base64 encoded icon data for different states"""
        # Base64 encoded monochrome icons (16x16 PNG)
        # Generated from CloudToLocalLLM assets
        icons = {
            "idle": (
                "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAAmJLR0QA/4ePzL8AAAAHdElNRQfpBgEO"
                "GAvVNB70AAAAgElEQVQoz83RMQ6CUBAE0PfRBgItFzDxVh7DeA8bGo9lSW04ApCYtYBGBGqn3VdMdhJh"
                "O0maz7X8SyajTnAEFzfVAgwad28h6njGWl5xDhly1WqBQkmG2OgZYgK7+ReQpK0/T2A0rIJRP72607gq"
                "frZ4aM1jHZyUC9BrjaT9ufkAKf46eVLyT+wAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYtMDFUMTM6"
                "MjI6MzkrMDA6MDAT6q3EAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjIyOjM5KzAwOjAw"
                "YrcVeAAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxNDoyNDoxMSswMDowMDQFC6IAAAAA"
                "SUVORK5CYII="
            ),
            "connected": (
                "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWEAQAAAA+LXjzAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1"
                "MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRP//FKsxzQAAAAd0SU1FB+kGAQ0KAtZaaNoAAAFBSURBVDjL"
                "7ZOxSwJhGMZ/BE3ieNNFS4ZDoxE4JCTBQS1tDSJNbeV04L8Rrm5BkARRDU1CWncIWY2dzrVoqzQFT8Nx"
                "pxdGlzaFD3zw8X3v++N5X94XZvrPMu7BvgYvD3oFbwfsCzAaU0ALKZC+PwVzEuhyAMhvSfsL0vuT5JxI"
                "K0cReOo35beDxMqZVCpJg4EiqjyMwo3mV8LcePDeG4C1BovzYJqQSEQjDjNg5cL4j5iOvQ3wyy4WpXZb"
                "Y+VcBY699ZhgvYCkGymdlvp9fathO2K1onMA4PYhmQTXHfnpQK/n3916+Lob07F9CZKVlWo1yTSlclmq"
                "VqVud+jW2gzc2udxp6IRTsXp+BZUbiNTcRcTDP7w+4nWtuS4kh4l51iyVqdfkqUfNi8zATRsSxPsOng5"
                "0DN4WbBbYLSmgM70B/oE5jIou4+gv28AAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYtMDFUMTM6MTA6"
                "MDIrMDA6MDACdUjhAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjEwOjAyKzAwOjAwcyjw"
                "XQAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxMzoxMDowMiswMDowMCQ90YIAAAAASUVO"
                "RK5CYII="
            ),
            "error": (
                "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAAmJLR0QA/4ePzL8AAAAHdElNRQfpBgEO"
                "GQRckDIkAAAAhklEQVQoz82RsQ2DQAxFnxN0MAL0dKyVhiZ7oIzBVCkyALQgqKKfwkFK4HQ1z4Ul+9mF"
                "bRJJsm8eWbGfugiU2Cb0dEw7IaflzhVJgxoRiUpPKQNWJv7GfQULM1wAO3Qdw1xIchZBxM8t5JcM5MSc"
                "QOFCScuD5fCLGzWYBLx5Me+EgpqwCQk+v2IykhHf6oIAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYt"
                "MDFUMTM6MjI6MzkrMDA6MDAT6q3EAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjIyOjM5"
                "KzAwOjAwYrcVeAAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxNDoyNTowNCswMDowMEVV"
                "T6UAAAAASUVORK5CYII="
            ),
        }
        
        icon_b64 = icons.get(state, icons["idle"])
        return base64.b64decode(icon_b64)