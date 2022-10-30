import axios from "axios";

export default axios.create({
  baseURL: "https://jumia-devops-challenge.eu/api/v1",
  headers: {
    "Content-type": "application/json",
  },
});
